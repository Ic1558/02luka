import { useState } from 'react'
import { FiCpu } from 'react-icons/fi'
import AIAssistant from './AIAssistant'

const AIFloatingButton = ({ context }) => {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <>
      {!isOpen && (
        <button
          onClick={() => setIsOpen(true)}
          className="fixed bottom-4 right-4 w-14 h-14 bg-gradient-to-br from-primary-600 to-accent-600 text-white rounded-full shadow-lg hover:shadow-xl transition-all hover:scale-110 z-40 flex items-center justify-center"
          title="AI Assistant"
        >
          <FiCpu className="w-6 h-6" />
          <span className="absolute -top-1 -right-1 w-3 h-3 bg-green-400 rounded-full border-2 border-white animate-pulse"></span>
        </button>
      )}

      <AIAssistant
        isOpen={isOpen}
        onClose={() => setIsOpen(false)}
        context={context}
      />
    </>
  )
}

export default AIFloatingButton
