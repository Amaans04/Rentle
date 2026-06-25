"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

const ownerNav = [
  { href: "/dashboard", label: "Dashboard", icon: "📊" },
  { href: "/rooms", label: "Rooms", icon: "🚪" },
  { href: "/tenants", label: "Tenants", icon: "👥" },
  { href: "/staff", label: "Staff", icon: "🧑‍💼" },
  { href: "/complaints", label: "Complaints", icon: "⚠️" },
  { href: "/notices", label: "Notices", icon: "📢" },
  { href: "/rent-records", label: "Rent Records", icon: "💰" },
  { href: "/settings", label: "Settings", icon: "⚙️" },
];

const managerNav = [
  { href: "/dashboard", label: "Dashboard", icon: "📊" },
  { href: "/tenants", label: "Tenants", icon: "👥" },
  { href: "/complaints", label: "Complaints", icon: "⚠️" },
  { href: "/notices", label: "Notices", icon: "📢" },
];

export default function Sidebar({ role }: { role: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const nav = role === "manager" ? managerNav : ownerNav;

  async function handleLogout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
  }

  return (
    <aside className="w-64 bg-trustBlue text-white min-h-screen flex flex-col">
      <div className="p-6 border-b border-white/20">
        <h1 className="font-poppins font-bold text-2xl">Rentle</h1>
        <p className="text-skyBlue text-sm mt-1">PG Management, Simplified</p>
      </div>
      <nav className="flex-1 p-4 space-y-1">
        {nav.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-colors ${
              pathname === item.href
                ? "bg-white/20 font-medium"
                : "hover:bg-white/10"
            }`}
          >
            <span>{item.icon}</span>
            <span className="font-inter text-sm">{item.label}</span>
          </Link>
        ))}
      </nav>
      <button
        onClick={handleLogout}
        className="m-4 px-4 py-3 text-left text-skyBlue hover:text-white transition-colors"
      >
        Logout
      </button>
    </aside>
  );
}
