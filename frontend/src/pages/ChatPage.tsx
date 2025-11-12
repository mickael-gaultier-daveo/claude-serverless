import { useState, useRef } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Send, Upload, FileText, LogOut, Key } from 'lucide-react';
import { chatService } from '../services/chatService';
import { ChangePasswordPage } from './ChangePasswordPage';

interface Message {
  id: string;
  content: string;
  role: 'user' | 'assistant';
  timestamp: number;
}

export function ChatPage() {
  const { user, logout } = useAuth();
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [files, setFiles] = useState<File[]>([]);
  const [showChangePassword, setShowChangePassword] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [conversationId, setConversationId] = useState<string>();

  const handleSendMessage = async () => {
    if (!inputMessage.trim() && files.length === 0) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      content: inputMessage,
      role: 'user',
      timestamp: Date.now(),
    };

    setMessages(prev => [...prev, userMessage]);
    const messageToSend = inputMessage;
    setInputMessage('');
    setIsLoading(true);

    try {
      // Traitement des fichiers en base64
      const fileContents: string[] = [];
      if (files.length > 0) {
        const processedFiles = await chatService.processFiles(files);
        for (const file of processedFiles) {
          fileContents.push(file.fileContent);
        }
        setFiles([]); // Clear files after processing
      }

      // Envoi du message à l'API
      const response = await chatService.sendMessage({
        message: messageToSend,
        conversationId,
        fileContents: fileContents.length > 0 ? fileContents : undefined,
      });

      // Mise à jour de l'ID de conversation
      if (response.conversationId) {
        setConversationId(response.conversationId);
      }
      
      const botMessage: Message = {
        id: (Date.now() + 1).toString(),
        content: response.response,
        role: 'assistant',
        timestamp: Date.now(),
      };

      setMessages(prev => [...prev, botMessage]);
    } catch (error) {
      console.error('Error sending message:', error);
      
      const errorMessage: Message = {
        id: (Date.now() + 1).toString(),
        content: "Désolé, une erreur s'est produite lors de l'envoi du message. Veuillez réessayer.",
        role: 'assistant',
        timestamp: Date.now(),
      };

      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleFileUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFiles = Array.from(event.target.files || []);
    setFiles(prev => [...prev, ...selectedFiles]);
  };

  const removeFile = (index: number) => {
    setFiles(prev => prev.filter((_: File, i: number) => i !== index));
  };

  // Si l'utilisateur veut changer son mot de passe
  if (showChangePassword) {
    return <ChangePasswordPage onClose={() => setShowChangePassword(false)} />;
  }

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-4 py-4 flex justify-between items-center">
          <div>
            <h1 className="text-xl font-semibold text-gray-900">Claude Chat</h1>
            <p className="text-sm text-gray-600">Bonjour, {user?.username}</p>
          </div>
          <div className="flex items-center space-x-3">
            <button
              onClick={() => setShowChangePassword(true)}
              className="btn-secondary flex items-center gap-2"
              title="Changer le mot de passe"
            >
              <Key className="h-4 w-4" />
              Mot de passe
            </button>
            <button
              onClick={logout}
              className="btn-secondary flex items-center gap-2"
            >
              <LogOut className="h-4 w-4" />
              Déconnexion
            </button>
          </div>
        </div>
      </header>

      {/* Chat Messages */}
      <div className="flex-1 max-w-4xl mx-auto w-full px-4 py-6 overflow-y-auto">
        <div className="space-y-4">
          {messages.length === 0 ? (
            <div className="text-center text-gray-500 py-12">
              <FileText className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>Aucun message pour le moment. Commencez une conversation !</p>
            </div>
          ) : (
            messages.map((message) => (
              <div
                key={message.id}
                className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                    message.role === 'user'
                      ? 'bg-primary-600 text-white'
                      : 'bg-white text-gray-900 shadow-sm border border-gray-200'
                  }`}
                >
                  <p className="whitespace-pre-wrap">{message.content}</p>
                  <p className={`text-xs mt-1 ${
                    message.role === 'user' ? 'text-primary-100' : 'text-gray-500'
                  }`}>
                    {new Date(message.timestamp).toLocaleTimeString()}
                  </p>
                </div>
              </div>
            ))
          )}
          
          {isLoading && (
            <div className="flex justify-start">
              <div className="bg-white text-gray-900 shadow-sm border border-gray-200 max-w-xs lg:max-w-md px-4 py-2 rounded-lg">
                <div className="flex items-center space-x-2">
                  <div className="animate-bounce">●</div>
                  <div className="animate-bounce delay-100">●</div>
                  <div className="animate-bounce delay-200">●</div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* File Preview */}
      {files.length > 0 && (
        <div className="max-w-4xl mx-auto w-full px-4 py-2">
          <div className="bg-white rounded-lg border border-gray-200 p-3">
            <p className="text-sm text-gray-600 mb-2">Fichiers sélectionnés :</p>
            <div className="flex flex-wrap gap-2">
              {files.map((file, index) => (
                <div key={index} className="flex items-center bg-gray-100 rounded-lg px-3 py-1">
                  <FileText className="h-4 w-4 mr-2 text-gray-600" />
                  <span className="text-sm text-gray-800">{file.name}</span>
                  <button
                    onClick={() => removeFile(index)}
                    className="ml-2 text-red-500 hover:text-red-700"
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Input Area */}
      <div className="max-w-4xl mx-auto w-full px-4 py-4">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="flex items-end p-3 space-x-3">
            <input
              type="file"
              ref={fileInputRef}
              onChange={handleFileUpload}
              multiple
              accept=".txt,.pdf,.docx,.csv,.json,.md"
              className="hidden"
            />
            
            <button
              onClick={() => fileInputRef.current?.click()}
              className="btn-secondary p-2"
              title="Ajouter des fichiers"
            >
              <Upload className="h-5 w-5" />
            </button>
            
            <textarea
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              placeholder="Tapez votre message..."
              className="flex-1 resize-none border-0 outline-none max-h-32 min-h-[2.5rem] py-2"
              rows={1}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  handleSendMessage();
                }
              }}
            />
            
            <button
              onClick={handleSendMessage}
              disabled={(!inputMessage.trim() && files.length === 0) || isLoading}
              className="btn-primary p-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Send className="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}