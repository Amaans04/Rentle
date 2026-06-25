"use client";

import { useEffect, useState } from "react";

interface Tenant {
  id: string;
  name: string;
  phone: string;
  roomNumber: string;
  rentStatus: string;
}

export default function TenantsPage() {
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [search, setSearch] = useState("");

  useEffect(() => {
    fetch("/api/owner/tenants")
      .then((r) => r.json())
      .then((d) => setTenants(d.tenants || []));
  }, []);

  const filtered = tenants.filter(
    (t) =>
      t.name.toLowerCase().includes(search.toLowerCase()) ||
      t.phone.includes(search)
  );

  const statusColor: Record<string, string> = {
    paid: "bg-teal/20 text-teal",
    unpaid: "bg-coral/20 text-coral",
  };

  return (
    <div>
      <h1 className="font-poppins font-bold text-2xl mb-6">Tenants</h1>
      <input
        placeholder="Search by name or phone..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="w-full max-w-md bg-skyBlue/25 px-4 py-3 rounded-xl mb-6 outline-none focus:ring-2 focus:ring-trustBlue font-inter"
      />
      <div className="bg-white rounded-2xl border border-skyBlue/60 overflow-hidden">
        <table className="w-full">
          <thead className="bg-skyBlue/20">
            <tr>
              <th className="text-left p-4 font-inter text-sm">Name</th>
              <th className="text-left p-4 font-inter text-sm">Phone</th>
              <th className="text-left p-4 font-inter text-sm">Room</th>
              <th className="text-left p-4 font-inter text-sm">Rent Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((t) => (
              <tr key={t.id} className="border-t border-skyBlue/20">
                <td className="p-4 font-poppins font-semibold">{t.name}</td>
                <td className="p-4 font-inter text-sm">+91 {t.phone}</td>
                <td className="p-4 font-inter text-sm">{t.roomNumber || "—"}</td>
                <td className="p-4">
                  <span className={`px-3 py-1 rounded-full text-xs font-inter capitalize ${statusColor[t.rentStatus] || "bg-amber/20 text-amber"}`}>
                    {t.rentStatus}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
