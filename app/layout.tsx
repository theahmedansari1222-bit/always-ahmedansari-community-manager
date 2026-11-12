import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = {
  title: "Always Ahmed Ansari — AI Community Manager",
  description: "A secure Instagram Creator and Threads comment management dashboard."
};
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
