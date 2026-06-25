"use client";

import { useEffect, useState } from "react";

interface Room {
  id: string;
  roomNumber: string;
  roomType: string;
  sharingCapacity: number;
  currentOccupancy: number;
  rentAmount: number;
  status: string;
}

export default function RoomsPage() {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({
    roomNumber: "",
    roomType: "single",
    sharingCapacity: 1,
    rentAmount: 0,
    mrpAmount: 0,
  });

  function loadRooms() {
    fetch("/api/owner/rooms")
      .then((r) => r.json())
      .then((d) => setRooms(d.rooms || []));
  }

  useEffect(() => { loadRooms(); }, []);

  async function addRoom(e: React.FormEvent) {
    e.preventDefault();
    await fetch("/api/owner/rooms", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(form),
    });
    setShowForm(false);
    loadRooms();
  }

  const statusColor: Record<string, string> = {
    vacant: "bg-teal/20 text-teal",
    partial: "bg-amber/20 text-amber",
    full: "bg-coral/20 text-coral",
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="font-poppins font-bold text-2xl">Rooms</h1>
        <button
          onClick={() => setShowForm(!showForm)}
          className="bg-coral text-white px-6 py-2 rounded-xl font-inter text-sm"
        >
          Add Room
        </button>
      </div>

      {showForm && (
        <form onSubmit={addRoom} className="bg-white rounded-2xl border border-skyBlue/60 p-6 mb-6 grid grid-cols-2 gap-4">
          <input placeholder="Room Number" value={form.roomNumber} onChange={(e) => setForm({ ...form, roomNumber: e.target.value })} className="bg-skyBlue/25 px-4 py-2 rounded-xl" required />
          <select value={form.roomType} onChange={(e) => setForm({ ...form, roomType: e.target.value })} className="bg-skyBlue/25 px-4 py-2 rounded-xl">
            <option value="single">Single</option>
            <option value="double">Double</option>
            <option value="triple">Triple</option>
            <option value="dormitory">Dormitory</option>
          </select>
          <input type="number" placeholder="Capacity" value={form.sharingCapacity} onChange={(e) => setForm({ ...form, sharingCapacity: +e.target.value })} className="bg-skyBlue/25 px-4 py-2 rounded-xl" required />
          <input type="number" placeholder="Rent Amount" value={form.rentAmount} onChange={(e) => setForm({ ...form, rentAmount: +e.target.value })} className="bg-skyBlue/25 px-4 py-2 rounded-xl" required />
          <input type="number" placeholder="MRP Amount" value={form.mrpAmount} onChange={(e) => setForm({ ...form, mrpAmount: +e.target.value })} className="bg-skyBlue/25 px-4 py-2 rounded-xl" required />
          <button type="submit" className="bg-coral text-white py-2 rounded-xl col-span-2">Create Room</button>
        </form>
      )}

      <div className="bg-white rounded-2xl border border-skyBlue/60 overflow-hidden">
        <table className="w-full">
          <thead className="bg-skyBlue/20">
            <tr>
              <th className="text-left p-4 font-inter text-sm">Room</th>
              <th className="text-left p-4 font-inter text-sm">Type</th>
              <th className="text-left p-4 font-inter text-sm">Occupancy</th>
              <th className="text-left p-4 font-inter text-sm">Rent</th>
              <th className="text-left p-4 font-inter text-sm">Status</th>
            </tr>
          </thead>
          <tbody>
            {rooms.map((room) => (
              <tr key={room.id} className="border-t border-skyBlue/20">
                <td className="p-4 font-poppins font-semibold">{room.roomNumber}</td>
                <td className="p-4 font-inter text-sm capitalize">{room.roomType}</td>
                <td className="p-4 font-inter text-sm">{room.currentOccupancy}/{room.sharingCapacity}</td>
                <td className="p-4 font-inter text-sm">₹{room.rentAmount}</td>
                <td className="p-4">
                  <span className={`px-3 py-1 rounded-full text-xs font-inter capitalize ${statusColor[room.status]}`}>
                    {room.status}
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
