"use client";

import { useEffect, useState } from "react";

interface Complaint {
  id: string;
  tenantName: string;
  roomNumber: string;
  type: string;
  description: string;
  status: string;
}

export default function ComplaintsPage() {
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [filter, setFilter] = useState("all");

  function loadComplaints() {
    fetch("/api/owner/complaints")
      .then((r) => r.json())
      .then((d) => setComplaints(d.complaints || []));
  }

  useEffect(() => { loadComplaints(); }, []);

  async function updateStatus(id: string, status: string) {
    await fetch(`/api/owner/complaints/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status }),
    });
    loadComplaints();
  }

  const filtered = filter === "all"
    ? complaints
    : complaints.filter((c) => c.status === filter);

  return (
    <div>
      <h1 className="font-poppins font-bold text-2xl mb-6">Complaints</h1>
      <div className="flex gap-2 mb-6">
        {["all", "open", "in_progress", "resolved"].map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-xl text-sm font-inter capitalize ${
              filter === f ? "bg-trustBlue text-white" : "bg-white border border-skyBlue/60"
            }`}
          >
            {f.replace("_", " ")}
          </button>
        ))}
      </div>
      <div className="space-y-4">
        {filtered.map((c) => (
          <div key={c.id} className="bg-white rounded-2xl border border-skyBlue/60 p-6">
            <div className="flex justify-between items-start">
              <div>
                <p className="font-poppins font-semibold">{c.tenantName} — Room {c.roomNumber}</p>
                <p className="text-sm text-charcoal/60 font-inter capitalize mt-1">{c.type}</p>
                <p className="font-inter text-sm mt-2">{c.description}</p>
              </div>
              <select
                value={c.status}
                onChange={(e) => updateStatus(c.id, e.target.value)}
                className="bg-skyBlue/25 px-3 py-2 rounded-xl text-sm font-inter capitalize"
              >
                <option value="open">Open</option>
                <option value="in_progress">In Progress</option>
                <option value="resolved">Resolved</option>
              </select>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
