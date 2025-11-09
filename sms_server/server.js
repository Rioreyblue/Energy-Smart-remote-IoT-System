const express = require("express");
const twilio = require("twilio");
const bodyParser = require("body-parser");
require("dotenv").config();

const app = express();
app.use(bodyParser.json());

// Check if testing mode is enabled
const isTestingMode = process.env.TESTING_MODE === 'true' || process.env.NODE_ENV === 'development';

const client = isTestingMode ? null : twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

app.post("/send-sms", async (req, res) => {
  try {
    const { to, message } = req.body;
    
    if (isTestingMode) {
      // Simulate SMS sending in testing mode
      console.log(`🧪 Testing Mode - Simulated SMS to ${to}: ${message}`);
      
      // Simulate delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      res.json({ 
        success: true, 
        sid: `testing_${Date.now()}`,
        testing: true,
        message: "SMS simulated in testing mode"
      });
    } else {
      // Real SMS sending
      const msg = await client.messages.create({
        body: message,
        from: process.env.TWILIO_PHONE_NUMBER,
        to,
      });
      res.json({ success: true, sid: msg.sid });
    }
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});

// Testing endpoint to get available testing codes
app.get("/testing-codes", (req, res) => {
  if (!isTestingMode) {
    return res.status(403).json({ error: "Testing mode not enabled" });
  }
  
  const testingCodes = {
    success: "123456",
    invalid: "000000", 
    expired: "999999",
    rate_limit: "111111",
    network_error: "222222"
  };
  
  res.json({
    testing: true,
    codes: testingCodes,
    instructions: "Use these codes to test different verification scenarios"
  });
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    testing_mode: isTestingMode,
    timestamp: new Date().toISOString()
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`✅ SMS Server running on port ${PORT}`));
