import { useState, useEffect, useRef } from 'react'
import { FiSend, FiX, FiMinimize2, FiMaximize2, FiCpu, FiLoader } from 'react-icons/fi'
import axios from 'axios'
import { toast } from 'react-toastify'

const AIAssistant = ({ isOpen, onClose, context }) => {
  const [messages, setMessages] = useState([
    {
      role: 'assistant',
      content: 'Hello! I\'m your AI assistant for architecture and construction. How can I help you today?'
    }
  ])
  const [inputMessage, setInputMessage] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [agentStatus, setAgentStatus] = useState({ is_online: false })
  const [isMinimized, setIsMinimized] = useState(false)
  const messagesEndRef = useRef(null)

  useEffect(() => {
    if (isOpen) {
      checkAgentHealth()
    }
  }, [isOpen])

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const checkAgentHealth = async () => {
    try {
      const response = await axios.get('/api/ai/agents/1/health')
      setAgentStatus(response.data.data)
    } catch (error) {
      console.error('Failed to check agent health:', error)
    }
  }

  const sendMessage = async (e) => {
    e.preventDefault()

    if (!inputMessage.trim() || isLoading) return

    const userMessage = inputMessage.trim()
    setInputMessage('')

    // Add user message to chat
    const newMessages = [
      ...messages,
      { role: 'user', content: userMessage }
    ]
    setMessages(newMessages)
    setIsLoading(true)

    try {
      const response = await axios.post('/api/ai/chat', {
        message: userMessage,
        context: context
      })

      setMessages([
        ...newMessages,
        {
          role: 'assistant',
          content: response.data.data.message,
          model: response.data.data.model,
          tokens: response.data.data.tokens
        }
      ])
    } catch (error) {
      toast.error('Failed to get AI response')
      setMessages([
        ...newMessages,
        {
          role: 'assistant',
          content: 'Sorry, I encountered an error. Please make sure the local AI service (Ollama) is running.'
        }
      ])
    } finally {
      setIsLoading(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed bottom-4 right-4 z-50">
      <div className={`bg-white rounded-lg shadow-2xl border transition-all ${
        isMinimized ? 'w-80 h-16' : 'w-96 h-[600px]'
      }`}>
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b bg-gradient-to-r from-primary-600 to-accent-600 rounded-t-lg">
          <div className="flex items-center space-x-3 text-white">
            <div className="relative">
              <FiCpu className="w-6 h-6" />
              {agentStatus.is_online && (
                <span className="absolute -top-1 -right-1 w-3 h-3 bg-green-400 rounded-full border-2 border-white"></span>
              )}
            </div>
            <div>
              <h3 className="font-semibold">AI Assistant</h3>
              <p className="text-xs opacity-90">
                {agentStatus.is_online ? 'Online' : 'Offline'}
                {agentStatus.latency_ms && ` • ${agentStatus.latency_ms}ms`}
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={() => setIsMinimized(!isMinimized)}
              className="p-1 hover:bg-white/20 rounded transition text-white"
            >
              {isMinimized ? <FiMaximize2 className="w-4 h-4" /> : <FiMinimize2 className="w-4 h-4" />}
            </button>
            <button
              onClick={onClose}
              className="p-1 hover:bg-white/20 rounded transition text-white"
            >
              <FiX className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Messages */}
        {!isMinimized && (
          <>
            <div className="flex-1 overflow-y-auto p-4 space-y-4 h-[460px] custom-scrollbar">
              {messages.map((message, index) => (
                <div
                  key={index}
                  className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-[80%] rounded-lg p-3 ${
                      message.role === 'user'
                        ? 'bg-primary-600 text-white'
                        : 'bg-gray-100 text-gray-900'
                    }`}
                  >
                    <p className="text-sm whitespace-pre-wrap">{message.content}</p>
                    {message.model && (
                      <p className="text-xs opacity-70 mt-2">
                        {message.model} • {message.tokens} tokens
                      </p>
                    )}
                  </div>
                </div>
              ))}

              {isLoading && (
                <div className="flex justify-start">
                  <div className="bg-gray-100 rounded-lg p-3">
                    <FiLoader className="w-5 h-5 animate-spin text-primary-600" />
                  </div>
                </div>
              )}

              <div ref={messagesEndRef} />
            </div>

            {/* Input */}
            <div className="p-4 border-t">
              {!agentStatus.is_online && (
                <div className="mb-3 p-2 bg-yellow-50 border border-yellow-200 rounded text-xs text-yellow-700">
                  AI service offline. Start Ollama with: <code className="bg-yellow-100 px-1">ollama serve</code>
                </div>
              )}

              <form onSubmit={sendMessage} className="flex items-center space-x-2">
                <input
                  type="text"
                  value={inputMessage}
                  onChange={(e) => setInputMessage(e.target.value)}
                  placeholder="Ask me anything..."
                  disabled={isLoading || !agentStatus.is_online}
                  className="flex-1 px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 disabled:bg-gray-100"
                />
                <button
                  type="submit"
                  disabled={isLoading || !inputMessage.trim() || !agentStatus.is_online}
                  className="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <FiSend className="w-5 h-5" />
                </button>
              </form>

              <p className="text-xs text-gray-500 mt-2 text-center">
                Powered by local AI • Your data stays private
              </p>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

export default AIAssistant
