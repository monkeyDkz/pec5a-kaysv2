"use client"

import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { TrendingUp, TrendingDown } from "lucide-react"

interface QuickStat {
  label: string
  value: string
  subValue: string
  trend: "up" | "down"
  trendValue: string
}

const stats: QuickStat[] = [
  {
    label: "Avg Order Value",
    value: "$67.50",
    subValue: "vs $62.30 last week",
    trend: "up",
    trendValue: "+8.3%",
  },
  {
    label: "Verification Rate",
    value: "94.2%",
    subValue: "vs 92.1% last week",
    trend: "up",
    trendValue: "+2.1%",
  },
  {
    label: "Response Time",
    value: "2.4 min",
    subValue: "vs 3.1 min last week",
    trend: "up",
    trendValue: "-22.6%",
  },
  {
    label: "Customer Satisfaction",
    value: "4.8/5.0",
    subValue: "Based on 234 reviews",
    trend: "up",
    trendValue: "+0.3",
  },
]

export function QuickStats() {
  return (
    <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-4">
      {stats.map((stat) => (
        <Card key={stat.label} className="border-border/50">
          <CardContent className="p-4">
            <div className="space-y-2">
              <p className="text-xs font-medium text-muted-foreground">{stat.label}</p>
              <div className="flex items-baseline justify-between">
                <p className="text-2xl font-bold">{stat.value}</p>
                <Badge variant="outline" className="bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border-0">
                  {stat.trend === "up" ? (
                    <TrendingUp className="mr-1 h-3 w-3" />
                  ) : (
                    <TrendingDown className="mr-1 h-3 w-3" />
                  )}
                  {stat.trendValue}
                </Badge>
              </div>
              <p className="text-xs text-muted-foreground">{stat.subValue}</p>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
