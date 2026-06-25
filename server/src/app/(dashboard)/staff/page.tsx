"use client";

import { useEffect, useState } from "react";

interface StaffMember {
  id: string;
  name: string;
  phone: string;
  role: string;
}

export default function StaffPage() {
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [phone, setPhone] = useState("");

  function loadStaff() {
    fetch("/api/owner/staff")
      .then((r) => r.json())
      .then((d) => setStaff(d.staff || []));
  }

  useEffect(() => { loadStaff(); }, []);

  async function inviteManager(e: React.FormEvent) {
    e.preventDefault();
    await fetch("/api/owner/staff/invite", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phone }),
    });
    setPhone("");
    loadStaff();
  }

  return (
    <div>
      <h1 className="font-poppins font-bold text-2xl mb-6">Staff & Managers</h1>
      <form onSubmit={inviteManager} className="flex gap-4 mb-6">
        <input
          placeholder="Manager phone number"
          value={phone}
          onChange={(e) => setPhone(e.target.value.replace(/\D/g, "").slice(0, 10))}
          className="bg-skyBlue/25 px-4 py-3 rounded-xl flex-1 max-w-xs outline-none focus:ring-2 focus:ring-trustBlue"
          maxLength={10}
        />
        <button type="submit" className="bg-coral text-white px-6 py-3 rounded-xl font-inter text-sm">
          Invite Manager
        </button>
      </form>
      <div className="bg-white rounded-2xl border border-skyBlue/60 overflow-hidden">
        <table className="w-full">
          <thead className="bg-skyBlue/20">
            <tr>
              <th className="text-left p-4 font-inter text-sm">Name</th>
              <th className="text-left p-4 font-inter text-sm">Phone</th>
              <th className="text-left p-4 font-inter text-sm">Role</th>
            </tr>
          </thead>
          <tbody>
            {staff.map((s) => (
              <tr key={s.id} className="border-t border-skyBlue/20">
                <td className="p-4 font-poppins font-semibold">{s.name}</td>
                <td className="p-4 font-inter text-sm">+91 {s.phone}</td>
                <td className="p-4 font-inter text-sm capitalize">{s.role}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
