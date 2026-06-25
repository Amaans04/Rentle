"use client";

import { useEffect, useState } from "react";

interface DashboardData {
  pg: { name: string };
  summary: {
    totalRooms: number;
    occupied: number;
    vacant: number;
    rentCollected: number;
  };
  activities: Array<{ type: string; amount?: number; description?: string }>;
}

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/api/owner/dashboard")
      .then(async (res) => {
        const json = await res.json();
        if (!res.ok) {
          throw new Error(json.error || "Failed to load dashboard");
        }
        if (!json.summary) {
          throw new Error("Invalid dashboard response");
        }
        setData(json);
      })
      .catch((e) => {
        setError(e instanceof Error ? e.message : "Failed to load dashboard");
      })
      .finally(() => setLoading(false));
  }, []);

  const summary = data?.summary;

  const cards = [
    { label: "Total Rooms", value: summary?.totalRooms ?? 0, color: "bg-trustBlue" },
    { label: "Occupied", value: summary?.occupied ?? 0, color: "bg-teal" },
    { label: "Vacant", value: summary?.vacant ?? 0, color: "bg-coral" },
    { label: "Rent Collected", value: `₹${summary?.rentCollected ?? 0}`, color: "bg-amber" },
  ];

  if (loading) {
    return (
      <div>
        <h1 className="font-poppins font-bold text-2xl mb-6">Dashboard</h1>
        <p className="text-charcoal/60 font-inter">Loading...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <h1 className="font-poppins font-bold text-2xl mb-6">Dashboard</h1>
        <div className="bg-coral/10 text-coral rounded-2xl p-6 font-inter text-sm">
          <p className="font-medium mb-2">{error}</p>
          {error === "Forbidden" && (
            <p className="text-charcoal/70">
              Complete PG setup in the Rentle mobile app first, then log in again
              here.
            </p>
          )}
        </div>
      </div>
    );
  }

  return (
    <div>
      <h1 className="font-poppins font-bold text-2xl mb-6">Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {cards.map((card) => (
          <div
            key={card.label}
            className={`${card.color} text-white rounded-2xl p-6`}
          >
            <p className="font-poppins font-bold text-3xl">{card.value}</p>
            <p className="font-inter text-sm mt-1 opacity-90">{card.label}</p>
          </div>
        ))}
      </div>
      <div className="bg-white rounded-2xl border border-skyBlue/60 p-6">
        <h2 className="font-poppins font-semibold text-lg mb-4">Recent Activity</h2>
        {!data?.activities?.length ? (
          <p className="text-charcoal/60 font-inter text-sm">No recent activity</p>
        ) : (
          <ul className="space-y-3">
            {data.activities.map((a, i) => (
              <li key={i} className="flex justify-between font-inter text-sm border-b border-skyBlue/20 pb-2">
                <span>{a.type === "payment" ? "Rent Payment" : "Complaint"}</span>
                <span className="text-charcoal/60">
                  {a.type === "payment" ? `₹${a.amount}` : a.description?.slice(0, 40)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
