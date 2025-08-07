#!/bin/bash

echo "🚀 Starting MedAssist Mobile API Server Setup"

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install

echo "🔧 Setting up environment..."
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Please create one with the following variables:"
    echo "MONGO_URI=mongodb+srv://amisha:1234@cluster0.5ohdhbh.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
    echo "JWT_SECRET=your-super-secret-jwt-key-here-change-in-production"
    echo "NODE_ENV=development"
    echo "PORT=5001"
    exit 1
fi

echo "🗄️  Testing MongoDB connection..."
node -e "
const mongoose = require('mongoose');
require('dotenv').config();
mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true, dbName: 'test' })
  .then(() => { console.log('✅ MongoDB connection successful'); process.exit(0); })
  .catch(err => { console.error('❌ MongoDB connection failed:', err.message); process.exit(1); });
"

if [ $? -eq 0 ]; then
    echo "🚀 Starting Mobile API Server..."
    npm start
else
    echo "❌ MongoDB connection failed. Please check your MONGO_URI in .env file."
    exit 1
fi
