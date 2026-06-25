"use client";

import { useEffect, useState } from "react";
import Sidebar from "@/components/Sidebar";

interface UserData {
  user: { name: string; role: string };
  pg: { name: string } | null;
}

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [data, setData] = useState<UserData | null>(null);

  useEffect(() => {
    fetch("/api/auth/me")
      .then((r) => r.json())
      .then(setData)
      .catch(() => {});
  }, []);

  return (
    <div className="flex min-h-screen">
      <Sidebar role={data?.user?.role || "owner"} />
      <div className="flex-1 flex flex-col">
        <header className="bg-white border-b border-skyBlue/40 px-8 py-4 flex justify-between items-center">
          <div>
            <h2 className="font-poppins font-semibold text-lg text-charcoal">
              {data?.pg?.name || "Rentle Dashboard"}
            </h2>
            <p className="text-sm text-charcoal/60 font-inter">
              {data?.user?.name || "Loading..."}
            </p>
          </div>
        </header>
        <main className="flex-1 p-8">{children}</main>
      </div>
    </div>
  );
}
