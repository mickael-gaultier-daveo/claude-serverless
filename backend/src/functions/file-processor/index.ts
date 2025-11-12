import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { v4 as uuidv4 } from 'uuid';
// @ts-ignore
import * as pdfParse from 'pdf-parse';
import * as mammoth from 'mammoth';
import { parse as csvParse } from 'csv-parse/sync';

const s3Client = new S3Client({ region: process.env.AWS_REGION || 'eu-west-1' });
const ddbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'eu-west-1' });
const ddbDocClient = DynamoDBDocumentClient.from(ddbClient);

interface FileUploadRequest {
  fileName: string;
  fileType: string;
  fileContent: string; // Base64 encoded
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  console.log('File processor invoked:', JSON.stringify(event, null, 2));

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,OPTIONS,POST,PUT',
  };

  try {
    if (event.httpMethod !== 'POST') {
      return {
        statusCode: 405,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Method not allowed' }),
      };
    }

    const body: FileUploadRequest = JSON.parse(event.body || '{}');
    if (!body.fileName || !body.fileType || !body.fileContent) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'fileName, fileType, and fileContent are required' }),
      };
    }

    // Extraction de l'utilisateur depuis le token Cognito
    const cognitoIdentity = event.requestContext.authorizer?.claims;
    const userId = cognitoIdentity?.sub;
    
    if (!userId) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const fileId = uuidv4();
    const timestamp = Date.now();
    
    // Décodage du contenu base64
    const fileBuffer = Buffer.from(body.fileContent, 'base64');
    
    // Upload du fichier vers S3
    const s3Key = `${userId}/${fileId}/${body.fileName}`;
    await s3Client.send(new PutObjectCommand({
      Bucket: process.env.UPLOAD_BUCKET,
      Key: s3Key,
      Body: fileBuffer,
      ContentType: body.fileType,
    }));

    // Extraction du contenu textuel
    let extractedText = '';
    let processingError = null;

    try {
      extractedText = await extractTextFromFile(fileBuffer, body.fileType, body.fileName);
    } catch (error) {
      console.error('Error extracting text from file:', error);
      processingError = error instanceof Error ? error.message : 'Unknown extraction error';
    }

    // Sauvegarde des métadonnées en DynamoDB
    const ttl = Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60); // 3 mois (90 jours)
    
    await ddbDocClient.send(new PutCommand({
      TableName: `${process.env.ENVIRONMENT}-file-metadata`,
      Item: {
        file_id: fileId,
        user_id: userId,
        file_name: body.fileName,
        file_type: body.fileType,
        file_size: fileBuffer.length,
        s3_key: s3Key,
        extracted_text: extractedText,
        upload_timestamp: timestamp,
        processing_error: processingError,
        ttl,
      },
    }));

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        fileId,
        fileName: body.fileName,
        fileSize: fileBuffer.length,
        extractedText,
        processingError,
        uploadTimestamp: timestamp,
      }),
    };

  } catch (error) {
    console.error('Error in file processor:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
};

async function extractTextFromFile(buffer: Buffer, mimeType: string, fileName: string): Promise<string> {
  const extension = fileName.split('.').pop()?.toLowerCase() || '';
  
  try {
    // PDF
    if (mimeType === 'application/pdf' || extension === 'pdf') {
      const pdfData = await pdfParse(buffer);
      return pdfData.text;
    }
    
    // DOCX
    if (mimeType === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' || extension === 'docx') {
      const result = await mammoth.extractRawText({ buffer });
      return result.value;
    }
    
    // CSV
    if (mimeType === 'text/csv' || extension === 'csv') {
      const csvText = buffer.toString('utf-8');
      const records = csvParse(csvText, { columns: true, skip_empty_lines: true });
      return JSON.stringify(records, null, 2);
    }
    
    // Fichiers texte (TXT, JSON, MD, etc.)
    if (mimeType.startsWith('text/') || 
        ['txt', 'json', 'md', 'js', 'ts', 'py', 'java', 'cpp', 'c', 'html', 'css', 'xml', 'yaml', 'yml'].includes(extension)) {
      return buffer.toString('utf-8');
    }
    
    // Autres types de fichiers
    throw new Error(`Unsupported file type: ${mimeType} (${extension})`);
    
  } catch (error) {
    console.error(`Error extracting text from ${mimeType}:`, error);
    throw error;
  }
}