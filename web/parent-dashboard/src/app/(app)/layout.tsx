import { AppNav } from "../../components/AppNav";
import { AuthGate } from "../../components/AuthGate";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <AuthGate>
      <div className="min-h-screen bg-zinc-50">
        <AppNav />
        {children}
      </div>
    </AuthGate>
  );
}
