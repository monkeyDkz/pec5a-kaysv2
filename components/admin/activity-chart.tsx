"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Bar, BarChart, ResponsiveContainer, XAxis, YAxis, Tooltip, CartesianGrid } from "recharts"

const data = [
  { name: "Mon", orders: 45, users: 12 },
  { name: "Tue", orders: 52, users: 19 },
  { name: "Wed", orders: 48, users: 15 },
  { name: "Thu", orders: 61, users: 23 },
  { name: "Fri", orders: 55, users: 18 },
  { name: "Sat", orders: 67, users: 28 },
  { name: "Sun", orders: 43, users: 14 },
]

export function ActivityChart() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Weekly Activity</CardTitle>
        <CardDescription>Orders and new user registrations over the past week</CardDescription>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
            <XAxis dataKey="name" className="text-xs" tick={{ fill: "hsl(var(--muted-foreground))" }} />
            <YAxis className="text-xs" tick={{ fill: "hsl(var(--muted-foreground))" }} />
            <Tooltip
              contentStyle={{
                backgroundColor: "hsl(var(--popover))",
                border: "1px solid hsl(var(--border))",
                borderRadius: "var(--radius)",
              }}
              labelStyle={{ color: "hsl(var(--popover-foreground))" }}
            />
            <Bar dataKey="orders" fill="hsl(var(--chart-1))" radius={[4, 4, 0, 0]} />
            <Bar dataKey="users" fill="hsl(var(--chart-2))" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}
