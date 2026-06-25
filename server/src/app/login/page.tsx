"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [step, setStep] = useState<"phone" | "otp">("phone");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function sendOtp() {
    setLoading(true);
    setError("");
    try {
      const res = await fetch("/api/auth/send-otp", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone, role: "owner" }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Failed to send OTP");
      setStep("otp");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error");
    } finally {
      setLoading(false);
    }
  }

  async function verifyOtp() {
    setLoading(true);
    setError("");
    try {
      const res = await fetch("/api/auth/verify-otp", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone, otp, role: "owner" }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Verification failed");
      router.push("/dashboard");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-warmSand p-4">
      <div className="bg-white rounded-2xl border border-skyBlue/60 p-8 w-full max-w-md shadow-sm">
        <div className="text-center mb-8">
          <h1 className="font-poppins font-bold text-3xl text-trustBlue">Rentle</h1>
          <p className="text-charcoal/60 font-inter text-sm mt-2">
            Owner & Manager Portal
          </p>
        </div>

        {error && (
          <div className="bg-coral/10 text-coral text-sm p-3 rounded-xl mb-4">
            {error}
          </div>
        )}

        {step === "phone" ? (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-inter text-charcoal mb-2">
                Phone Number
              </label>
              <div className="flex">
                <span className="bg-skyBlue/25 px-4 py-3 rounded-l-xl text-charcoal font-inter">
                  +91
                </span>
                <input
                  type="tel"
                  maxLength={10}
                  value={phone}
                  onChange={(e) => setPhone(e.target.value.replace(/\D/g, ""))}
                  className="flex-1 bg-skyBlue/25 px-4 py-3 rounded-r-xl outline-none focus:ring-2 focus:ring-trustBlue font-inter"
                  placeholder="9876543210"
                />
              </div>
            </div>
            <button
              onClick={sendOtp}
              disabled={loading || phone.length !== 10}
              className="w-full bg-coral text-white py-3 rounded-xl font-inter font-medium hover:bg-coral/90 disabled:opacity-50 transition-colors"
            >
              {loading ? "Sending..." : "Send OTP"}
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-inter text-charcoal mb-2">
                Enter OTP
              </label>
              <input
                type="text"
                maxLength={6}
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
                className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl outline-none focus:ring-2 focus:ring-trustBlue font-inter text-center text-2xl tracking-widest"
                placeholder="000000"
              />
            </div>
            <button
              onClick={verifyOtp}
              disabled={loading || otp.length !== 6}
              className="w-full bg-coral text-white py-3 rounded-xl font-inter font-medium hover:bg-coral/90 disabled:opacity-50 transition-colors"
            >
              {loading ? "Verifying..." : "Verify & Login"}
            </button>
            <button
              onClick={() => setStep("phone")}
              className="w-full text-trustBlue text-sm font-inter"
            >
              Change number
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
