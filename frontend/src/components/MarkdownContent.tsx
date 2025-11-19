import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeSanitize from 'rehype-sanitize';
import './MarkdownContent.css';

interface MarkdownContentProps {
  content: string;
  isUser?: boolean;
}

export function MarkdownContent({ content, isUser = false }: MarkdownContentProps) {
  return (
    <div className={`markdown-content ${isUser ? 'text-white' : 'text-gray-900'}`}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        rehypePlugins={[rehypeSanitize]}
        components={{
          // Titres
          h1: ({ children }) => (
            <h1 className={`text-2xl font-bold mb-3 mt-4 ${isUser ? 'text-white' : 'text-gray-900'}`}>
              {children}
            </h1>
          ),
          h2: ({ children }) => (
            <h2 className={`text-xl font-bold mb-2 mt-3 ${isUser ? 'text-white' : 'text-gray-900'}`}>
              {children}
            </h2>
          ),
          h3: ({ children }) => (
            <h3 className={`text-lg font-bold mb-2 mt-3 ${isUser ? 'text-white' : 'text-gray-900'}`}>
              {children}
            </h3>
          ),
          h4: ({ children }) => (
            <h4 className={`text-base font-bold mb-2 mt-2 ${isUser ? 'text-white' : 'text-gray-900'}`}>
              {children}
            </h4>
          ),
          
          // Paragraphes
          p: ({ children }) => (
            <p className="mb-3 leading-relaxed">
              {children}
            </p>
          ),
          
          // Listes à puces
          ul: ({ children }) => (
            <ul className="list-disc list-inside mb-3 space-y-1 ml-2">
              {children}
            </ul>
          ),
          
          // Listes numérotées
          ol: ({ children }) => (
            <ol className="list-decimal list-inside mb-3 space-y-1 ml-2">
              {children}
            </ol>
          ),
          
          // Items de liste
          li: ({ children }) => (
            <li className="ml-2">
              {children}
            </li>
          ),
          
          // Texte en gras
          strong: ({ children }) => (
            <strong className="font-bold">
              {children}
            </strong>
          ),
          
          // Texte en italique
          em: ({ children }) => (
            <em className="italic">
              {children}
            </em>
          ),
          
          // Code inline
          code: ({ children }) => (
            <code className={`px-1.5 py-0.5 rounded text-sm font-mono ${
              isUser ? 'bg-white/20' : 'bg-gray-100'
            }`}>
              {children}
            </code>
          ),
          
          // Bloc de code
          pre: ({ children }) => (
            <pre className={`p-3 rounded-lg mb-3 overflow-x-auto text-sm font-mono ${
              isUser ? 'bg-white/20' : 'bg-gray-100'
            }`}>
              {children}
            </pre>
          ),
          
          // Citations
          blockquote: ({ children }) => (
            <blockquote className={`border-l-4 pl-4 italic mb-3 ${
              isUser ? 'border-white/40' : 'border-gray-300'
            }`}>
              {children}
            </blockquote>
          ),
          
          // Séparateur horizontal
          hr: () => (
            <hr className={`my-4 ${isUser ? 'border-white/20' : 'border-gray-200'}`} />
          ),
          
          // Liens
          a: ({ href, children }) => (
            <a
              href={href}
              target="_blank"
              rel="noopener noreferrer"
              className={`underline hover:opacity-80 ${
                isUser ? 'text-white' : 'text-primary-600'
              }`}
            >
              {children}
            </a>
          ),
          
          // Tableaux
          table: ({ children }) => (
            <div className="overflow-x-auto mb-3">
              <table className={`min-w-full divide-y ${
                isUser ? 'divide-white/20' : 'divide-gray-200'
              }`}>
                {children}
              </table>
            </div>
          ),
          thead: ({ children }) => (
            <thead className={isUser ? 'bg-white/10' : 'bg-gray-50'}>
              {children}
            </thead>
          ),
          tbody: ({ children }) => (
            <tbody className={`divide-y ${
              isUser ? 'divide-white/10' : 'divide-gray-100'
            }`}>
              {children}
            </tbody>
          ),
          th: ({ children }) => (
            <th className="px-3 py-2 text-left text-xs font-bold uppercase tracking-wider">
              {children}
            </th>
          ),
          td: ({ children }) => (
            <td className="px-3 py-2 text-sm">
              {children}
            </td>
          ),
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  );
}
