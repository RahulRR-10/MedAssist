@echo off
echo 🚀 Starting MedAssist Mobile Server

echo 📦 Installing Node.js dependencies...
call npm install

if errorlevel 1 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)

echo 🔧 Checking environment...
if not exist ".env" (
    echo ⚠️  .env file not found. Please create one with the following variables:
    echo MONGO_URI=mongodb+srv://amisha:1234@cluster0.5ohdhbh.mongodb.net/?retryWrites=true^&w=majority^&appName=Cluster0
    echo JWT_SECRET=your-super-secret-jwt-key-here-change-in-production
    echo NODE_ENV=development
    echo PORT=5001
    pause
    exit /b 1
)

echo 🚀 Starting Mobile Server...
echo 📱 All-in-one server: Authentication + Prescription Management + Notifications
echo 🔗 Access server at: http://localhost:5000
echo 🔗 Health check: http://localhost:5000/api/health
echo.
call npm start

pause
