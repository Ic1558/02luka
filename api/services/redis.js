import { createClient } from 'redis'
import dotenv from 'dotenv'

dotenv.config()

const redisClient = createClient({
  socket: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  },
  password: process.env.REDIS_PASSWORD || undefined
})

redisClient.on('error', (err) => {
  console.error('Redis Client Error:', err)
})

redisClient.on('connect', () => {
  console.log('Redis Client Connected')
})

redisClient.on('ready', () => {
  console.log('Redis Client Ready')
})

export async function initializeRedis() {
  if (!redisClient.isOpen) {
    await redisClient.connect()
  }
  return redisClient
}

// Pub/Sub for real-time events
export async function publishEvent(channel, data) {
  try {
    await redisClient.publish(channel, JSON.stringify(data))
  } catch (error) {
    console.error('Error publishing event:', error)
  }
}

// Cache helpers
export async function setCache(key, value, expirationInSeconds = 3600) {
  try {
    await redisClient.setEx(key, expirationInSeconds, JSON.stringify(value))
  } catch (error) {
    console.error('Error setting cache:', error)
  }
}

export async function getCache(key) {
  try {
    const data = await redisClient.get(key)
    return data ? JSON.parse(data) : null
  } catch (error) {
    console.error('Error getting cache:', error)
    return null
  }
}

export async function deleteCache(key) {
  try {
    await redisClient.del(key)
  } catch (error) {
    console.error('Error deleting cache:', error)
  }
}

export default redisClient
