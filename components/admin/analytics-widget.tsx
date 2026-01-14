"use client"

import type React from "react"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { TrendingUp, TrendingDown, Users, Package, DollarSign, Clock } from "lucide-react"

interface AnalyticsStat {
  label: string
  value: string
  change: number
  icon: React.ReactNode
  trend: "up" | "down"
}

const stats: AnalyticsStat[] = [
  {
    label: "Active Users (24h)",
    value: "1,234",
    change: 12.5,
    icon: <Users className="h-4 w-4" />,
    trend: "up",
  },
  {
    label: "Orders Today",
    value: "89",
    change: -5.2,
    icon: <Package className="h-4 w-4" />,
    trend: "down",
  },
  {
    label: "Revenue Today",
    value: "$4,567",
    change: 8.3,
    icon: <DollarSign className="h-4 w-4" />,
    trend: "up",
  },
  {
    label: "Avg Response Time",
    value: "2.4 min",
    change: -15.8,
    icon: <Clock className="h-4 w-4" />,
    trend: "up",
  },
]

export function AnalyticsWidget() {
  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      {stats.map((stat) => (
        <Card key={stat.label}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{stat.label}</CardTitle>
            {stat.icon}
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stat.value}</div>
            <div className="flex items-center gap-1 mt-1">
              {stat.trend === "up" ? (
                <TrendingUp className="h-4 w-4 text-emerald-500" />
              ) : (
                <TrendingDown className="h-4 w-4 text-red-500" />
              )}
              <span
                className={`text-xs font-medium ${
                  stat.trend === "up" ? "text-emerald-600 dark:text-emerald-400" : "text-red-600 dark:text-red-400"
                }`}
              >
                {Math.abs(stat.change)}% vs last period
              </span>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
