export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  files?: { name: string; type: string }[];
}

export interface FileContent {
  fileName: string;
  fileType: string;
  fileContent: string; // base64
}

export interface ChatRequest {
  message: string;
  conversationId?: string;
  files?: FileContent[]; // Nouveau format avec métadonnées
}

export interface ChatResponse {
  response: string;
  conversationId: string;
}

export interface ConversationHistory {
  conversationId: string;
  messages: ChatMessage[];
}

export interface ConversationListItem {
  conversationId: string;
  timestamp: number;
  messageCount: number;
  preview: string;
}

export interface ConversationListResponse {
  conversations: ConversationListItem[];
  count: number;
}

class ChatService {
  private streamUrl: string;

  constructor() {
    // URL de la Lambda Function URL pour le streaming avec Lambda Web Adapter
    this.streamUrl = 'https://bvwj44lx75sujykpsjhpf5kdu40ftzvw.lambda-url.eu-west-3.on.aws';
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
      
      const response = await fetch(`${this.streamUrl}/chat`, {
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

  async *sendMessageStream(request: ChatRequest): AsyncGenerator<{ type: 'chunk' | 'start' | 'end'; content?: string; conversationId?: string; timestamp?: number }, void, unknown> {
    try {
      const headers = await this.getAuthHeaders();
      
      const response = await fetch(`${this.streamUrl}/chat`, {
        method: 'POST',
        headers,
        body: JSON.stringify(request),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const reader = response.body?.getReader();
      if (!reader) {
        throw new Error('No response body');
      }

      const decoder = new TextDecoder();
      let buffer = '';

      try {
        while (true) {
          const { done, value } = await reader.read();
          
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';

          for (const line of lines) {
            if (!line.trim()) continue;

            try {
              const data = JSON.parse(line);
              
              if (data.type === 'chunk' && data.content) {
                yield { type: 'chunk', content: data.content };
              } else if (data.type === 'start') {
                yield { type: 'start', conversationId: data.conversationId, timestamp: data.timestamp };
              } else if (data.type === 'end') {
                yield { type: 'end', timestamp: data.timestamp };
              } else if (data.type === 'error') {
                throw new Error(data.content || 'Streaming error');
              }
            } catch (e) {
              if (e instanceof SyntaxError) {
                console.warn('Failed to parse line:', line);
              } else {
                throw e;
              }
            }
          }
        }
      } finally {
        reader.releaseLock();
      }
    } catch (error) {
      console.error('Error in streaming chat:', error);
      throw new Error('Failed to stream message');
    }
  }

  async listConversations(): Promise<ConversationListResponse> {
    try {
      const headers = await this.getAuthHeaders();
      
      const response = await fetch(`${this.streamUrl}/conversations`, {
        method: 'GET',
        headers,
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error listing conversations:', error);
      throw new Error('Failed to list conversations');
    }
  }

  async getConversationHistory(conversationId: string): Promise<ConversationHistory> {
    try {
      const headers = await this.getAuthHeaders();
      
      const response = await fetch(`${this.streamUrl}/conversations/${conversationId}`, {
        method: 'GET',
        headers,
      });

      if (!response.ok) {
        if (response.status === 404) {
          return { conversationId, messages: [] };
        }
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error getting conversation history:', error);
      throw new Error('Failed to get conversation history');
    }
  }

  async deleteConversation(conversationId: string): Promise<void> {
    try {
      const headers = await this.getAuthHeaders();
      
      const response = await fetch(`${this.streamUrl}/conversations/${conversationId}`, {
        method: 'DELETE',
        headers,
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
    } catch (error) {
      console.error('Error deleting conversation:', error);
      throw new Error('Failed to delete conversation');
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