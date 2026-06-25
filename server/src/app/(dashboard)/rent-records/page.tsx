"use client";

import { useEffect, useState } from "react";

interface Record {
  id: string;
  tenantName: string;
  month: number;
  year: number;
  amount: number;
  status: string;
  paidAt?: { _seconds: number };
}

export default function RentRecordsPage() {
  const [records, setRecords] = useState<Record[]>([]);

  function loadRecords() {
    fetch("/api/owner/rent-records")
      .then((r) => r.json())
      .then((d) => setRecords(d.records || []));
  }

  useEffect(() => { loadRecords(); }, []);

  async function generateRecords() {
    await fetch("/api/owner/rent-records", { method: "POST" });
    loadRecords();
  }

  async function markPaid(id: string) {
    await fetch("/api/payments/mark-paid", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ recordId: id, method: "cash" }),
    });
    loadRecords();
  }

  const months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="font-poppins font-bold text-2xl">Rent Records</h1>
        <button onClick={generateRecords} className="bg-trustBlue text-white px-6 py-2 rounded-xl font-inter text-sm">
          Generate This Month
        </button>
      </div>
      <div className="bg-white rounded-2xl border border-skyBlue/60 overflow-hidden">
        <table className="w-full">
          <thead className="bg-skyBlue/20">
            <tr>
              <th className="text-left p-4 font-inter text-sm">Tenant</th>
              <th className="text-left p-4 font-inter text-sm">Month</th>
              <th className="text-left p-4 font-inter text-sm">Amount</th>
              <th className="text-left p-4 font-inter text-sm">Status</th>
              <th className="text-left p-4 font-inter text-sm">Action</th>
            </tr>
          </thead>
          <tbody>
            {records.map((r) => (
              <tr key={r.id} className="border-t border-skyBlue/20">
                <td className="p-4 font-poppins font-semibold">{r.tenantName}</td>
                <td className="p-4 font-inter text-sm">{months[r.month]} {r.year}</td>
                <td className="p-4 font-inter text-sm">₹{r.amount}</td>
                <td className="p-4">
                  <span className={`px-3 py-1 rounded-full text-xs font-inter capitalize ${
                    r.status === "paid" ? "bg-teal/20 text-teal" : "bg-coral/20 text-coral"
                  }`}>
                    {r.status}
                  </span>
                </td>
                <td className="p-4">
                  {r.status === "unpaid" && (
                    <button onClick={() => markPaid(r.id)} className="text-trustBlue text-sm font-inter">
                      Mark Paid (Cash)
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
