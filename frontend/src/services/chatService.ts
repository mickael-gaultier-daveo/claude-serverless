import { AWS_CONFIG } from '../config/aws';

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
}

export interface FileContent {
  fileName: string;
  fileType: string;
  fileContent: string; // base64
}

export interface ChatRequest {
  message: string;
  conversationId?: string;
  fileContents?: string[]; // Array of base64 file contents
}

export interface ChatResponse {
  response: string;
  conversationId: string;
}

class ChatService {
  private apiUrl: string;

  constructor() {
    this.apiUrl = AWS_CONFIG.apiUrl;
  }

  private async getAuthHeaders(): Promise<Headers> {
    const token = localStorage.getItem('idToken');
    const headers = new Headers({
      'Content-Type': 'application/json',
    });

    if (token) {
      headers.append('Authorization', `Bearer ${token}`);
    }

    return headers;
  }

  async sendMessage(request: ChatRequest): Promise<ChatResponse> {
    try {
      const headers = await this.getAuthHeaders();
      
      const response = await fetch(`${this.apiUrl}/chat`, {
        method: 'POST',
        headers,
        body: JSON.stringify(request),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error sending chat message:', error);
      throw new Error('Failed to send message');
    }
  }

  async processFiles(files: File[]): Promise<FileContent[]> {
    const fileContents: FileContent[] = [];

    for (const file of files) {
      try {
        const base64Content = await this.fileToBase64(file);
        fileContents.push({
          fileName: file.name,
          fileType: file.type || this.getFileTypeFromName(file.name),
          fileContent: base64Content
        });
      } catch (error) {
        console.error(`Error processing file ${file.name}:`, error);
        throw new Error(`Failed to process file: ${file.name}`);
      }
    }

    return fileContents;
  }

  private fileToBase64(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => {
        if (typeof reader.result === 'string') {
          // Supprimer le préfixe "data:type/subtype;base64," pour ne garder que le base64
          const base64 = reader.result.split(',')[1];
          resolve(base64);
        } else {
          reject(new Error('Failed to read file as base64'));
        }
      };
      reader.onerror = error => reject(error);
    });
  }

  private getFileTypeFromName(fileName: string): string {
    const extension = fileName.split('.').pop()?.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }
}

export const chatService = new ChatService();