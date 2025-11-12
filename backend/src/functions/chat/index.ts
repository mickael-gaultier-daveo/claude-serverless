import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { BedrockRuntimeClient, InvokeModelCommand } from '@aws-sdk/client-bedrock-runtime';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { v4 as uuidv4 } from 'uuid';

const bedrockClient = new BedrockRuntimeClient({ region: process.env.AWS_REGION || 'eu-west-1' });
const ddbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'eu-west-1' });
const ddbDocClient = DynamoDBDocumentClient.from(ddbClient);

interface ChatRequest {
  message: string;
  conversationId?: string;
  fileContents?: string[];
}

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  console.log('Chat handler invoked:', JSON.stringify(event, null, 2));

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,OPTIONS,POST,PUT',
  };

  try {
    // Vérification de la méthode HTTP
    if (event.httpMethod !== 'POST') {
      return {
        statusCode: 405,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Method not allowed' }),
      };
    }

    // Parse du body
    const body: ChatRequest = JSON.parse(event.body || '{}');
    if (!body.message) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Message is required' }),
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

    const conversationId = body.conversationId || uuidv4();
    const timestamp = Date.now();

    // Récupération de l'historique de conversation si existant
    let conversationHistory: ChatMessage[] = [];
    if (body.conversationId) {
      try {
        const historyResponse = await ddbDocClient.send(new QueryCommand({
          TableName: process.env.DYNAMODB_TABLE,
          KeyConditionExpression: 'user_id = :userId AND conversation_id = :conversationId',
          ExpressionAttributeValues: {
            ':userId': userId,
            ':conversationId': conversationId,
          },
          ScanIndexForward: true,
        }));

        if (historyResponse.Items) {
          conversationHistory = historyResponse.Items
            .sort((a, b) => a.timestamp - b.timestamp)
            .flatMap(item => item.messages || []);
        }
      } catch (error) {
        console.error('Error fetching conversation history:', error);
        // Continue sans historique en cas d'erreur
      }
    }

    // Construction du contexte pour Claude
    let contextMessages = [...conversationHistory];
    
    // Ajout du contenu des fichiers si fourni
    if (body.fileContents && body.fileContents.length > 0) {
      const filesContext = body.fileContents
        .map((content, index) => `<file_${index + 1}>\n${content}\n</file_${index + 1}>`)
        .join('\n\n');
      
      contextMessages.push({
        role: 'user',
        content: `Voici les fichiers fournis en contexte:\n\n${filesContext}`,
        timestamp: timestamp - 1,
      });
    }

    // Ajout du message utilisateur
    const userMessage: ChatMessage = {
      role: 'user',
      content: body.message,
      timestamp,
    };
    contextMessages.push(userMessage);

    // Préparation du prompt pour Claude
    const messages = contextMessages.map(msg => ({
      role: msg.role,
      content: msg.content,
    }));

    // Appel à Bedrock Claude
    const claudeRequest = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: 4000,
      messages: messages,
      system: "Tu es un assistant IA utile et bienveillant. Tu peux analyser des documents et répondre aux questions à leur sujet. Réponds de manière claire et structurée.",
    };

    const command = new InvokeModelCommand({
      modelId: 'anthropic.claude-3-5-sonnet-20241022-v2:0',
      contentType: 'application/json',
      body: JSON.stringify(claudeRequest),
    });

    const response = await bedrockClient.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));
    
    const assistantMessage: ChatMessage = {
      role: 'assistant',
      content: responseBody.content[0].text,
      timestamp: Date.now(),
    };

    // Sauvegarde des messages en DynamoDB
    const updatedMessages = [...contextMessages, assistantMessage];
    const ttl = Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60); // 3 mois (90 jours)

    await ddbDocClient.send(new PutCommand({
      TableName: process.env.DYNAMODB_TABLE,
      Item: {
        user_id: userId,
        conversation_id: conversationId,
        messages: updatedMessages.slice(-20), // Garde seulement les 20 derniers messages
        timestamp,
        ttl,
      },
    }));

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        response: assistantMessage.content,
        conversationId,
        timestamp: assistantMessage.timestamp,
      }),
    };

  } catch (error) {
    console.error('Error in chat handler:', error);
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