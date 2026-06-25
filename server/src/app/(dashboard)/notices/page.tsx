"use client";

import { useEffect, useState } from "react";

interface Notice {
  id: string;
  title: string;
  body: string;
  targetRole: string;
  createdAt: { _seconds: number };
}

export default function NoticesPage() {
  const [notices, setNotices] = useState<Notice[]>([]);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [targetRole, setTargetRole] = useState("all");

  function loadNotices() {
    fetch("/api/owner/notices")
      .then((r) => r.json())
      .then((d) => setNotices(d.notices || []));
  }

  useEffect(() => { loadNotices(); }, []);

  async function createNotice(e: React.FormEvent) {
    e.preventDefault();
    await fetch("/api/owner/notices", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, body, targetRole }),
    });
    setTitle("");
    setBody("");
    loadNotices();
  }

  return (
    <div>
      <h1 className="font-poppins font-bold text-2xl mb-6">Notice Board</h1>
      <form onSubmit={createNotice} className="bg-white rounded-2xl border border-skyBlue/60 p-6 mb-6 space-y-4">
        <input placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl" required />
        <textarea placeholder="Notice body" value={body} onChange={(e) => setBody(e.target.value)} className="w-full bg-skyBlue/25 px-4 py-3 rounded-xl h-24" required />
        <select value={targetRole} onChange={(e) => setTargetRole(e.target.value)} className="bg-skyBlue/25 px-4 py-3 rounded-xl">
          <option value="all">All</option>
          <option value="tenant">Tenants</option>
          <option value="manager">Managers</option>
        </select>
        <button type="submit" className="bg-coral text-white px-6 py-3 rounded-xl font-inter text-sm">Post Notice</button>
      </form>
      <div className="space-y-4">
        {notices.map((n) => (
          <div key={n.id} className="bg-white rounded-2xl border border-skyBlue/60 p-6">
            <h3 className="font-poppins font-semibold">{n.title}</h3>
            <p className="font-inter text-sm mt-2 text-charcoal/80">{n.body}</p>
            <p className="text-xs text-charcoal/40 mt-2 font-inter capitalize">For: {n.targetRole}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
