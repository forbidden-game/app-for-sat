import { AppNav } from "../../components/AppNav";
import { AuthGate } from "../../components/AuthGate";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <AuthGate>
      <div className="min-h-screen bg-white">
        <AppNav />
        {children}
      </div>
    </AuthGate>
  );
}
