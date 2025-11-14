import { useCallback, useEffect, useMemo, useState } from 'react'
import axios from 'axios'
import { toast } from 'react-toastify'
import {
  FiAlertTriangle,
  FiCheckCircle,
  FiFileText,
  FiLoader,
  FiRefreshCcw
} from 'react-icons/fi'

const DEFAULT_ENDPOINTS = {
  summary: '/api/reports/summary',
  list: '/api/reports/list',
  latest: '/api/reports/latest'
}

function resolveReportbotBase() {
  if (typeof window === 'undefined') {
    return ''
  }

  const envValue = (import.meta?.env?.VITE_REPORTBOT_URL || '').trim()
  if (envValue) return envValue

  const windowGlobal = window.__REPORTBOT__
  if (windowGlobal && typeof windowGlobal.apiBase === 'string' && windowGlobal.apiBase.trim()) {
    return windowGlobal.apiBase.trim()
  }

  const windowOverride = typeof window.REPORTBOT_API_URL === 'string' ? window.REPORTBOT_API_URL.trim() : ''
  if (windowOverride) return windowOverride

  return window.location.origin
}

function buildUrl(path, base) {
  const fallbackOrigin = typeof window !== 'undefined' ? window.location.origin : 'http://localhost'

  try {
    const baseUrl = base ? new URL(base, fallbackOrigin) : new URL(fallbackOrigin)
    return new URL(path, baseUrl).toString()
  } catch (error) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path
    }
    const trimmedOrigin = fallbackOrigin.replace(/\/$/, '')
    const trimmedPath = path.startsWith('/') ? path.slice(1) : path
    return `${trimmedOrigin}/${trimmedPath}`
  }
}

function formatDate(value) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  }).format(date)
}

function formatSize(bytes) {
  const num = Number(bytes)
  if (!Number.isFinite(num) || num < 0) return '—'
  if (num === 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  const exponent = Math.min(Math.floor(Math.log10(num) / Math.log10(1024)), units.length - 1)
  const value = num / 1024 ** exponent
  const precision = value >= 100 ? 0 : value >= 10 ? 1 : 2
  return `${value.toFixed(precision)} ${units[exponent]}`
}

function getStatusStyles(status) {
  const normalised = String(status || '').toLowerCase()
  if (normalised === 'ok') return 'bg-green-100 text-green-700 border-green-200'
  if (normalised === 'warn' || normalised === 'warning') return 'bg-amber-100 text-amber-700 border-amber-200'
  if (normalised === 'fail' || normalised === 'critical') return 'bg-red-100 text-red-700 border-red-200'
  return 'bg-gray-100 text-gray-700 border-gray-200'
}

function normalisePayload(payload) {
  if (!payload) return {}
  if (payload && typeof payload === 'object' && 'data' in payload && typeof payload.data === 'object') {
    return payload.data
  }
  return payload
}

const Reports = () => {
  const [summary, setSummary] = useState(null)
  const [reports, setReports] = useState([])
  const [proof, setProof] = useState([])
  const [latestReport, setLatestReport] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [lastUpdated, setLastUpdated] = useState(null)

  const reportbotBase = useMemo(() => resolveReportbotBase(), [])

  const endpoints = useMemo(() => ({
    summary: buildUrl(DEFAULT_ENDPOINTS.summary, reportbotBase),
    list: buildUrl(DEFAULT_ENDPOINTS.list, reportbotBase),
    latest: buildUrl(DEFAULT_ENDPOINTS.latest, reportbotBase)
  }), [reportbotBase])

  const displayBase = useMemo(() => {
    try {
      const url = new URL(endpoints.summary)
      return `${url.protocol}//${url.host}`
    } catch (err) {
      return reportbotBase || (typeof window !== 'undefined' ? window.location.origin : '')
    }
  }, [endpoints.summary, reportbotBase])

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)

    try {
      const [summaryRes, listRes, latestRes] = await Promise.all([
        axios.get(endpoints.summary, { timeout: 8000 }),
        axios.get(endpoints.list, { timeout: 8000 }),
        axios.get(endpoints.latest, { timeout: 8000 })
      ])

      const summaryPayload = normalisePayload(summaryRes.data)
      const listPayload = normalisePayload(listRes.data)
      const latestPayload = normalisePayload(latestRes.data)

      setSummary(summaryPayload || null)
      setReports(Array.isArray(listPayload?.reports) ? listPayload.reports : [])
      setProof(Array.isArray(listPayload?.proof) ? listPayload.proof : [])
      setLatestReport(latestPayload?.report || null)
      setLastUpdated(summaryPayload?.timestamp || summaryPayload?.generated_at || new Date().toISOString())
    } catch (err) {
      const message = err?.response?.data?.error || err?.message || 'Unable to load report data'
      setError(message)
      toast.error(message)
    } finally {
      setLoading(false)
    }
  }, [endpoints.latest, endpoints.list, endpoints.summary])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const statusLabel = (summary?.status || summary?.level || 'unknown').toString().toUpperCase()
  const statusClassName = getStatusStyles(summary?.status || summary?.level)

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div className="space-y-1">
          <h1 className="text-2xl lg:text-3xl font-display font-bold text-gray-900">Reports &amp; Evidence</h1>
          <p className="text-gray-600">Live status and recent artifacts sourced from the reportbot pipeline.</p>
          <p className="text-xs text-gray-400">API base: {displayBase || 'auto-detected'}</p>
        </div>
        <button
          onClick={fetchData}
          disabled={loading}
          className="btn-secondary inline-flex items-center justify-center space-x-2"
        >
          <FiRefreshCcw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          <span>{loading ? 'Refreshing…' : 'Refresh data'}</span>
        </button>
      </div>

      {error && (
        <div className="border border-red-200 bg-red-50 text-red-700 px-4 py-3 rounded-lg flex items-start space-x-2">
          <FiAlertTriangle className="w-5 h-5 mt-0.5" />
          <div>
            <p className="font-medium">Failed to load report data</p>
            <p className="text-sm">{error}</p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <div className="card space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Operational summary</h2>
              {lastUpdated && (
                <p className="text-xs text-gray-500">Last updated: {formatDate(lastUpdated)}</p>
              )}
            </div>
            <span className={`px-3 py-1 rounded-full text-xs font-semibold border ${statusClassName}`}>
              {statusLabel}
            </span>
          </div>

          <p className="text-sm text-gray-600">
            {summary?.message || 'No summary message available.'}
          </p>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-2">
              <p className="text-xs text-gray-500">Reports</p>
              <p className="text-lg font-semibold text-gray-900">{summary?.totals?.reports ?? reports.length ?? 0}</p>
            </div>
            <div className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-2">
              <p className="text-xs text-gray-500">Proof artifacts</p>
              <p className="text-lg font-semibold text-gray-900">{summary?.totals?.proof ?? proof.length ?? 0}</p>
            </div>
            <div className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-2">
              <p className="text-xs text-gray-500">Combined</p>
              <p className="text-lg font-semibold text-gray-900">{summary?.totals?.combined ?? (reports.length + proof.length)}</p>
            </div>
          </div>

          {summary?.recent?.length > 0 && (
            <div className="space-y-2">
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Recent alerts</p>
              <ul className="space-y-1 text-sm text-gray-700">
                {summary.recent.map((alert) => (
                  <li key={`${alert.timestamp}-${alert.message}`} className="flex items-center space-x-2">
                    <FiAlertTriangle className="w-4 h-4 text-amber-500" />
                    <span className="font-medium">{alert.level}</span>
                    <span className="text-gray-500">{formatDate(alert.timestamp)}</span>
                    <span className="text-gray-600">{alert.message}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>

        <div className="card space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Latest markdown report</h2>
              {latestReport?.modified && (
                <p className="text-xs text-gray-500">Generated {formatDate(latestReport.modified)}</p>
              )}
            </div>
            {latestReport?.size && (
              <span className="text-xs text-gray-500">{formatSize(latestReport.size)}</span>
            )}
          </div>

          {loading && !latestReport ? (
            <div className="flex items-center justify-center h-48 text-gray-500">
              <FiLoader className="w-6 h-6 animate-spin mr-2" />
              <span>Loading latest report…</span>
            </div>
          ) : latestReport ? (
            <div className="rounded-lg border border-gray-200 bg-gray-50 p-4 space-y-3">
              <div className="flex items-center space-x-2 text-sm text-gray-700">
                <FiFileText className="w-4 h-4 text-primary-600" />
                <span className="font-medium truncate">{latestReport.name}</span>
              </div>
              <pre className="text-xs text-gray-700 bg-white border border-gray-200 rounded-lg p-3 max-h-64 overflow-auto whitespace-pre-wrap">
                {latestReport.content || 'No content available.'}
              </pre>
            </div>
          ) : (
            <p className="text-sm text-gray-500">No markdown reports available.</p>
          )}
        </div>
      </div>

      <div className="card space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">Recent files</h2>
          <FiCheckCircle className="w-5 h-5 text-primary-600" />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-3">
            <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-wide">Reports</h3>
            {reports.length === 0 ? (
              <p className="text-sm text-gray-500">No recent reports found.</p>
            ) : (
              <ul className="space-y-3">
                {reports.slice(0, 6).map((item) => (
                  <li key={`${item.relativePath || item.name}`}
                    className="rounded-lg border border-gray-200 p-3 bg-gray-50">
                    <div className="flex items-center justify-between">
                      <span className="font-medium text-gray-900 truncate">{item.name}</span>
                      <span className="text-xs text-gray-500">{formatSize(item.size)}</span>
                    </div>
                    <p className="text-xs text-gray-500">{formatDate(item.modified)}</p>
                    {item.relativePath && (
                      <p className="text-xs text-gray-400 truncate">/{item.relativePath}</p>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="space-y-3">
            <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-wide">Proof</h3>
            {proof.length === 0 ? (
              <p className="text-sm text-gray-500">No recent proof artifacts.</p>
            ) : (
              <ul className="space-y-3">
                {proof.slice(0, 6).map((item) => (
                  <li key={`${item.relativePath || item.name}`}
                    className="rounded-lg border border-gray-200 p-3 bg-gray-50">
                    <div className="flex items-center justify-between">
                      <span className="font-medium text-gray-900 truncate">{item.name}</span>
                      <span className="text-xs text-gray-500">{formatSize(item.size)}</span>
                    </div>
                    <p className="text-xs text-gray-500">{formatDate(item.modified)}</p>
                    {item.relativePath && (
                      <p className="text-xs text-gray-400 truncate">/{item.relativePath}</p>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default Reports
