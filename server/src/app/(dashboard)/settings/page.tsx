"use client";

import { useEffect, useState } from "react";

interface PgData {
  name: string;
  address: string;
  city: string;
  contactPhone: string;
  rentDueDate: number;
  upiId: string;
  genderType: string;
}

export default function SettingsPage() {
  const [pg, setPg] = useState<PgData>({
    name: "", address: "", city: "", contactPhone: "",
    rentDueDate: 1, upiId: "", genderType: "unisex",
  });
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    fetch("/api/auth/me")
      .then((r) => r.json())
      .then((d) => {
        if (d.pg) {
          setPg({
            name: d.pg.name || "",
            address: d.pg.address || "",
            city: d.pg.city || "",
            contactPhone: d.pg.contactPhone || "",
            rentDueDate: d.pg.rentDueDate || 1,
            upiId: d.pg.upiId || "",
            genderType: d.pg.genderType || "unisex",
          });
        }
      });
  }, []);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    await fetch("/api/owner/settings", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(pg),
    });
    setSaved(true);
    setTimeout(() => setSaved(false), 3000);
  }

  return (
    <div>
      <h1 className="font-poppins font-bold text-2xl mb-6">Settings</h1>
      <form onSubmit={handleSave} className="bg-white rounded-2xl border border-skyBlue/60 p-6 max-w-2xl space-y-4">
        <div>
          <label className="block text-sm font-inter mb-1">Property Name</label>
          <input value={pg.name} onChange={(e) => setPg({ ...pg, name: e.target.value })} className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl" />
        </div>
        <div>
          <label className="block text-sm font-inter mb-1">Address</label>
          <textarea value={pg.address} onChange={(e) => setPg({ ...pg, address: e.target.value })} className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl h-20" />
        </div>
        <div>
          <label className="block text-sm font-inter mb-1">City</label>
          <input value={pg.city} onChange={(e) => setPg({ ...pg, city: e.target.value })} className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl" />
        </div>
        <div>
          <label className="block text-sm font-inter mb-1">Contact Phone</label>
          <input value={pg.contactPhone} onChange={(e) => setPg({ ...pg, contactPhone: e.target.value })} className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl" />
        </div>
        <div>
          <label className="block text-sm font-inter mb-1">UPI ID (for tenant payments)</label>
          <input value={pg.upiId} onChange={(e) => setPg({ ...pg, upiId: e.target.value })} className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl" placeholder="owner@upi" />
        </div>
        <div>
          <label className="block text-sm font-inter mb-1">Rent Due Date</label>
          <select value={pg.rentDueDate} onChange={(e) => setPg({ ...pg, rentDueDate: +e.target.value })} className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl">
            {Array.from({ length: 28 }, (_, i) => i + 1).map((d) => (
              <option key={d} value={d}>{d}{d === 1 ? "st" : d === 2 ? "nd" : d === 3 ? "rd" : "th"} of month</option>
            ))}
          </select>
        </div>
        <button type="submit" className="bg-coral text-white px-8 py-3 rounded-xl font-inter">
          Save Changes
        </button>
        {saved && <p className="text-teal text-sm font-inter">Settings saved!</p>}
      </form>
    </div>
  );
}
