const mongoose = require("mongoose");

// MongoDB Schema for medications
const medicationSchema = new mongoose.Schema({
  name: { type: String, required: true },
  beforeAfterFood: { type: String, enum: ["Before", "After"], required: true },
  schedules: [
    {
      startDate: { type: Date, required: true },
      endDate: { type: Date, required: true },
      dosage: { type: String, required: true },
      times: [{ type: String, required: true }],
    },
  ],
});

// MongoDB Schema for prescription mobile users
const prescriptionMobileSchema = new mongoose.Schema(
  {
    username: { type: String, unique: true, required: true },
    password: { type: String, required: true },
    prescriptions: [medicationSchema],
    fcmToken: { type: String },
    lastProcessed: { type: Date, default: Date.now },
  },
  {
    timestamps: true, // Adds createdAt and updatedAt automatically
  }
);

// Export the model, checking if it already exists
const PrescriptionMobile =
  mongoose.models.PrescriptionMobile ||
  mongoose.model("PrescriptionMobile", prescriptionMobileSchema);

module.exports = {
  PrescriptionMobile,
  medicationSchema,
  prescriptionMobileSchema,
};
