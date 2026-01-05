import { AdminGate } from "@/components/AdminGate";
import { AdminNav } from "@/components/AdminNav";

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <AdminGate>
      <div className="min-h-screen bg-zinc-50">
        <AdminNav />
        {children}
      </div>
    </AdminGate>
  );
}
