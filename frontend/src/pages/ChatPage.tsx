import { useState, useRef, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Send, Upload, FileText, LogOut, Key, Paperclip, History, ChevronDown, Trash2 } from 'lucide-react';
import { chatService, ConversationListItem } from '../services/chatService';
import { ChangePasswordPage } from './ChangePasswordPage';
import { MarkdownContent } from '../components/MarkdownContent';
import { UsageModal } from '../components/UsageModal';

interface Message {
  id: string;
  content: string;
  role: 'user' | 'assistant';
  timestamp: number;
  files?: { name: string; type: string }[];
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
  const [oldConversationId, setOldConversationId] = useState<string | null>(null); // Pour fork
  const [conversationsList, setConversationsList] = useState<ConversationListItem[]>([]);
  const [showHistoryDropdown, setShowHistoryDropdown] = useState(false);
  
  // Statistiques d'utilisation
  const [monthlyUsage, setMonthlyUsage] = useState<{ inputTokens: number; outputTokens: number; costUsd: number } | null>(null);
  const [showUsageModal, setShowUsageModal] = useState(false);
  
  // Ref pour le scroll automatique
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Charger l'historique au démarrage
  useEffect(() => {
    const loadHistory = async () => {
      try {
        setIsLoading(true);
        
        // Récupérer la liste de toutes les conversations de l'utilisateur
        const convList = await chatService.listConversations();
        setConversationsList(convList.conversations || []);
        
        // Récupérer les statistiques d'utilisation du mois en cours
        try {
          const usage = await chatService.getCurrentMonthUsage();
          setMonthlyUsage(usage);
        } catch (error) {
          console.error('Error loading usage stats:', error);
        }
        
        if (convList.conversations && convList.conversations.length > 0) {
          // Charger la conversation la plus récente (première de la liste car triée par timestamp décroissant)
          const mostRecentConversation = convList.conversations[0];
          const history = await chatService.getConversationHistory(mostRecentConversation.conversationId);
          
          if (history.messages && history.messages.length > 0) {
            // Convertir les messages DynamoDB en messages de l'interface
            const loadedMessages: Message[] = history.messages.map((msg, index) => ({
              id: `${msg.timestamp}-${index}`,
              content: msg.content,
              role: msg.role,
              timestamp: msg.timestamp,
              files: msg.files,
            }));
            
            setMessages(loadedMessages);
            setConversationId(mostRecentConversation.conversationId);
            console.log(`Loaded conversation ${mostRecentConversation.conversationId} with ${loadedMessages.length} messages`);
          }
        } else {
          console.log('No conversations found, starting fresh');
        }
      } catch (error) {
        console.error('Error loading conversation history:', error);
        // En cas d'erreur, on ignore et démarre une nouvelle conversation
      } finally {
        setIsLoading(false);
      }
    };

    loadHistory();
  }, []);

  // Sauvegarder le conversationId dans le localStorage quand il change (pour référence)
  useEffect(() => {
    if (conversationId) {
      localStorage.setItem('currentConversationId', conversationId);
    }
  }, [conversationId]);

  // Scroll automatique vers le bas quand les messages changent
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSendMessage = async () => {
    if (!inputMessage.trim() && files.length === 0) return;

    // Si on reprend une ancienne conversation (oldConversationId !== null), on la forke
    if (oldConversationId !== null) {
      try {
        // Supprimer l'ancienne version
        await chatService.deleteConversation(oldConversationId);
        console.log(`Forked conversation ${oldConversationId}, old version deleted`);
        
        // Reset pour créer une nouvelle conversation
        setConversationId(undefined);
        setOldConversationId(null);
        
        // Recharger la liste des conversations
        const convList = await chatService.listConversations();
        setConversationsList(convList.conversations || []);
      } catch (error) {
        console.error('Error forking conversation:', error);
      }
    }

    // Traitement des fichiers d'abord pour avoir les métadonnées
    let processedFiles: { fileName: string; fileType: string; fileContent: string }[] = [];
    if (files.length > 0) {
      processedFiles = await chatService.processFiles(files);
    }

    const userMessage: Message = {
      id: Date.now().toString(),
      content: inputMessage,
      role: 'user',
      timestamp: Date.now(),
      files: processedFiles.length > 0 ? processedFiles.map(f => ({ name: f.fileName, type: f.fileType })) : undefined,
    };

    setMessages(prev => [...prev, userMessage]);
    const messageToSend = inputMessage;
    setInputMessage('');
    setFiles([]); // Clear files after adding to message
    setIsLoading(true);

    // Créer un message assistant vide pour le streaming
    const assistantMessageId = (Date.now() + 1).toString();
    const assistantMessage: Message = {
      id: assistantMessageId,
      content: '',
      role: 'assistant',
      timestamp: Date.now(),
    };
    setMessages(prev => [...prev, assistantMessage]);

    try {
      // Envoi du message avec streaming (conversationId undefined = nouvelle conversation)
      const stream = chatService.sendMessageStream({
        message: messageToSend,
        conversationId,
        files: processedFiles.length > 0 ? processedFiles : undefined,
      });

      // Consommer le stream et mettre à jour le message en temps réel
      let fullResponse = '';
      for await (const event of stream) {
        if (event.type === 'start' && event.conversationId) {
          setConversationId(event.conversationId);
        } else if (event.type === 'chunk' && event.content) {
          fullResponse += event.content;
          setMessages(prev => prev.map(msg => 
            msg.id === assistantMessageId 
              ? { ...msg, content: fullResponse }
              : msg
          ));
        }
      }
      
    } catch (error) {
      console.error('Error sending message:', error);
      
      // Mettre à jour le message assistant avec l'erreur
      setMessages(prev => prev.map(msg => 
        msg.id === assistantMessageId 
          ? { 
              ...msg, 
              content: "Désolé, une erreur s'est produite lors de l'envoi du message. Veuillez réessayer." 
            }
          : msg
      ));
    } finally {
      setIsLoading(false);
      
      // Rafraîchir les statistiques d'utilisation après l'envoi du message
      // Petit délai pour laisser le backend enregistrer les stats
      setTimeout(async () => {
        try {
          const usage = await chatService.getCurrentMonthUsage();
          setMonthlyUsage(usage);
        } catch (error) {
          console.error('Error refreshing usage stats:', error);
        }
      }, 1000);
    }
  };

  const handleFileUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFiles = Array.from(event.target.files || []);
    setFiles(prev => [...prev, ...selectedFiles]);
  };

  const removeFile = (index: number) => {
    setFiles(prev => prev.filter((_: File, i: number) => i !== index));
  };

  const startNewConversation = () => {
    setMessages([]);
    setConversationId(undefined);
    setOldConversationId(null);
    localStorage.removeItem('currentConversationId');
  };

  const handleDeleteAllHistory = async () => {
    const confirmed = window.confirm(
      '⚠️ Êtes-vous sûr de vouloir supprimer TOUT votre historique ?\n\n' +
      'Cette action est irréversible et supprimera :\n' +
      '• Toutes vos conversations sauvegardées\n' +
      '• La conversation en cours\n' +
      '• Tous les messages dans DynamoDB'
    );
    
    if (!confirmed) return;
    
    try {
      setIsLoading(true);
      const result = await chatService.deleteAllConversations();
      setMessages([]);
      setConversationId(undefined);
      setOldConversationId(null);
      setConversationsList([]);
      localStorage.removeItem('currentConversationId');
      alert(`✅ ${result.message}`);
    } catch (error) {
      console.error('Error deleting all history:', error);
      alert('❌ Erreur lors de la suppression de l\'historique');
    } finally {
      setIsLoading(false);
    }
  };

  const loadOldConversation = async (convId: string) => {
    try {
      setIsLoading(true);
      const history = await chatService.getConversationHistory(convId);
      
      if (history.messages && history.messages.length > 0) {
        const loadedMessages: Message[] = history.messages.map((msg, index) => ({
          id: `${msg.timestamp}-${index}`,
          content: msg.content,
          role: msg.role,
          timestamp: msg.timestamp,
          files: msg.files,
        }));
        
        setMessages(loadedMessages);
        setConversationId(convId);
        setOldConversationId(convId); // Marquer comme ancienne conversation
        setShowHistoryDropdown(false);
        console.log(`Loaded old conversation ${convId} with ${loadedMessages.length} messages`);
      }
    } catch (error) {
      console.error('Error loading old conversation:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // Si l'utilisateur veut changer son mot de passe
  if (showChangePassword) {
    return <ChangePasswordPage onClose={() => setShowChangePassword(false)} />;
  }

  return (
    <div 
      className="min-h-screen flex flex-col relative"
      style={{
        backgroundImage: 'url(/background.webp)',
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundAttachment: 'fixed'
      }}
    >
      {/* Overlay léger pour améliorer la lisibilité */}
      <div className="absolute inset-0 bg-white/10" />
      
      {/* Contenu par-dessus le fond */}
      <div className="relative z-10 flex flex-col min-h-screen">
      
      {/* Header fixe qui reste visible en haut */}
      <header className="sticky top-0 z-20 bg-white/95 backdrop-blur-sm shadow-sm border-b border-gray-200">
        <div className="w-full px-4 py-4 flex justify-between items-center">
          <div>
            <h1 className="text-xl font-semibold text-gray-900">Claude Chat</h1>
            <p className="text-sm text-gray-700">Bonjour, {user?.username}</p>
            {monthlyUsage && (
              <button
                onClick={() => setShowUsageModal(true)}
                className="text-xs text-gray-500 mt-1 hover:text-primary-600 transition-colors cursor-pointer"
              >
                Coût du mois: <span className="font-medium text-primary-600 underline">${monthlyUsage.costUsd.toFixed(4)}</span>
                {' '}({monthlyUsage.inputTokens.toLocaleString()} tokens entrée, {monthlyUsage.outputTokens.toLocaleString()} tokens sortie)
              </button>
            )}
          </div>
          <div className="flex items-center space-x-3">
            <button
              onClick={startNewConversation}
              className="btn-secondary flex items-center gap-2"
              title="Nouvelle conversation"
            >
              <FileText className="h-4 w-4" />
              Nouvelle
            </button>
            
            {/* Bouton Historique avec dropdown */}
            <div className="relative">
              <button
                onClick={() => setShowHistoryDropdown(!showHistoryDropdown)}
                className="btn-secondary flex items-center gap-2"
                title="Historique des conversations"
                disabled={conversationsList.length === 0}
              >
                <History className="h-4 w-4" />
                Historique
                <ChevronDown className="h-3 w-3" />
              </button>
              
              {showHistoryDropdown && conversationsList.length > 0 && (
                <div className="absolute right-0 mt-2 w-80 bg-white rounded-lg shadow-lg border border-gray-200 max-h-96 overflow-y-auto z-50">
                  {conversationsList.map((conv) => (
                    <button
                      key={conv.conversationId}
                      onClick={() => loadOldConversation(conv.conversationId)}
                      className={`w-full text-left px-4 py-3 hover:bg-gray-50 border-b border-gray-100 ${
                        conv.conversationId === conversationId ? 'bg-blue-50' : ''
                      }`}
                    >
                      <div className="text-sm font-medium text-gray-900 truncate">
                        {conv.preview}
                      </div>
                      <div className="text-xs text-gray-500 mt-1">
                        {conv.messageCount} messages • {new Date(conv.timestamp).toLocaleDateString('fr-FR', {
                          day: 'numeric',
                          month: 'short',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
            
            {/* Bouton Supprimer l'historique */}
            <button
              onClick={handleDeleteAllHistory}
              className="btn-secondary flex items-center gap-2 text-red-600 hover:bg-red-50 hover:border-red-300"
              title="Supprimer tout l'historique"
              disabled={conversationsList.length === 0 && messages.length === 0}
            >
              <Trash2 className="h-4 w-4" />
              Tout supprimer
            </button>
            
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
      <div className="flex-1 w-full px-4 py-6 overflow-y-auto">
        <div className="space-y-4">
          {messages.length === 0 ? (
            <div className="text-center text-white drop-shadow-lg py-12">
              <FileText className="h-12 w-12 mx-auto mb-4 opacity-70 drop-shadow-md" />
              <p>Aucun message pour le moment. Commencez une conversation !</p>
            </div>
          ) : (
            messages.map((message) => (
              <div
                key={message.id}
                className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`w-[90%] px-5 py-4 rounded-lg ${
                    message.role === 'user'
                      ? 'bg-primary-600 text-white'
                      : 'bg-white text-gray-900 shadow-sm border border-gray-200'
                  }`}
                >
                  {message.files && message.files.length > 0 && (
                    <div className="mb-3 pb-2 border-b border-white/20">
                      {message.files.map((file, idx) => (
                        <div key={idx} className="flex items-center gap-2 text-xs opacity-90">
                          <Paperclip className="h-3 w-3" />
                          <span className="font-medium">{file.name}</span>
                        </div>
                      ))}
                    </div>
                  )}
                  <MarkdownContent 
                    content={message.content} 
                    isUser={message.role === 'user'}
                  />
                  <p className={`text-xs mt-2 ${
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
              <div className="bg-white text-gray-900 shadow-sm border border-gray-200 w-[90%] px-4 py-2 rounded-lg">
                <div className="flex items-center space-x-2">
                  <div className="animate-bounce">●</div>
                  <div className="animate-bounce delay-100">●</div>
                  <div className="animate-bounce delay-200">●</div>
                </div>
              </div>
            </div>
          )}
          
          {/* Élément invisible pour le scroll automatique */}
          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* File Preview */}
      {files.length > 0 && (
        <div className="w-full px-4 py-2">
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
      <div className="w-full px-4 py-4">
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
      
      {/* Modal des statistiques d'utilisation */}
      <UsageModal 
        isOpen={showUsageModal} 
        onClose={() => setShowUsageModal(false)} 
      />
    </div>
  );
}