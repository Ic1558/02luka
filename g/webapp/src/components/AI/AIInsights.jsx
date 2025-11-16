import { useState, useEffect } from 'react'
import { FiCpu, FiCheckCircle, FiAlertCircle, FiLoader, FiRefreshCw } from 'react-icons/fi'
import axios from 'axios'
import { toast } from 'react-toastify'

const AIInsights = ({ contextData }) => {
  const [task, setTask] = useState(null)
  const [loading, setLoading] = useState(false)
  const [insights, setInsights] = useState(null)

  useEffect(() => {
    if (task && task.status === 'processing') {
      const interval = setInterval(() => {
        checkTaskStatus()
      }, 2000)

      return () => clearInterval(interval)
    }
  }, [task])

  const checkTaskStatus = async () => {
    if (!task) return

    try {
      const response = await axios.get(`/api/ai/tasks/${task.id}`)
      const updatedTask = response.data.data

      setTask(updatedTask)

      if (updatedTask.status === 'completed') {
        setInsights(updatedTask.result)
        setLoading(false)
      } else if (updatedTask.status === 'failed') {
        toast.error('AI analysis failed')
        setLoading(false)
      }
    } catch (error) {
      console.error('Failed to check task status:', error)
    }
  }

  const analyzeContext = async () => {
    setLoading(true)
    setInsights(null)

    try {
      const response = await axios.post('/api/ai/analyze-context', {
        context_id: contextData.id,
        context_data: contextData
      })

      setTask({ id: response.data.task_id, status: 'processing' })
      toast.info('AI analysis started...')
    } catch (error) {
      toast.error('Failed to start AI analysis')
      setLoading(false)
    }
  }

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold text-gray-900 flex items-center space-x-2">
          <FiCpu className="w-5 h-5 text-primary-600" />
          <span>AI Site Analysis</span>
        </h3>

        <button
          onClick={analyzeContext}
          disabled={loading}
          className="btn-primary flex items-center space-x-2 disabled:opacity-50"
        >
          {loading ? (
            <>
              <FiLoader className="w-4 h-4 animate-spin" />
              <span>Analyzing...</span>
            </>
          ) : (
            <>
              <FiRefreshCw className="w-4 h-4" />
              <span>{insights ? 'Re-analyze' : 'Analyze'}</span>
            </>
          )}
        </button>
      </div>

      {loading && !insights && (
        <div className="flex flex-col items-center justify-center py-12">
          <FiLoader className="w-12 h-12 text-primary-600 animate-spin mb-4" />
          <p className="text-gray-600">AI is analyzing the site context...</p>
          <p className="text-sm text-gray-500 mt-1">This may take 10-30 seconds</p>
        </div>
      )}

      {insights && (
        <div className="space-y-4">
          <div className="flex items-start space-x-3 p-4 bg-green-50 border border-green-200 rounded-lg">
            <FiCheckCircle className="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" />
            <div className="flex-1">
              <p className="text-sm font-medium text-green-900 mb-2">Analysis Complete</p>
              <div className="prose prose-sm max-w-none text-gray-700 whitespace-pre-wrap">
                {insights}
              </div>
            </div>
          </div>

          {task && (
            <div className="text-xs text-gray-500 flex items-center justify-between">
              <span>
                Processed in {task.processing_time_ms}ms
              </span>
              {task.result_data && (
                <span>
                  {task.result_data.model} • {task.result_data.tokens} tokens
                </span>
              )}
            </div>
          )}
        </div>
      )}

      {!loading && !insights && (
        <div className="text-center py-8">
          <div className="w-16 h-16 mx-auto mb-4 bg-primary-100 rounded-full flex items-center justify-center">
            <FiCpu className="w-8 h-8 text-primary-600" />
          </div>
          <p className="text-gray-600 mb-2">Get AI-powered insights for this site</p>
          <p className="text-sm text-gray-500">
            Analyzes opportunities, constraints, and recommendations
          </p>
        </div>
      )}
    </div>
  )
}

export default AIInsights
