"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { ShoppingCart, UserPlus, FileCheck, AlertCircle } from "lucide-react"

const recentActivities = [
  {
    id: "1",
    type: "order",
    user: "John Doe",
    action: "placed an order",
    time: "5 min ago",
    icon: ShoppingCart,
    badge: "New",
  },
  {
    id: "2",
    type: "user",
    user: "Jane Smith",
    action: "registered as driver",
    time: "12 min ago",
    icon: UserPlus,
    badge: "Pending",
  },
  {
    id: "3",
    type: "verification",
    user: "Bob Wilson",
    action: "submitted ID verification",
    time: "1 hour ago",
    icon: FileCheck,
    badge: "Review",
  },
  {
    id: "4",
    type: "dispute",
    user: "Alice Brown",
    action: "opened a dispute",
    time: "2 hours ago",
    icon: AlertCircle,
    badge: "Urgent",
  },
  {
    id: "5",
    type: "order",
    user: "Charlie Davis",
    action: "order delivered",
    time: "3 hours ago",
    icon: ShoppingCart,
    badge: "Complete",
  },
]

export function RecentActivity() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Recent Activity</CardTitle>
        <CardDescription>Latest actions across the platform</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {recentActivities.map((activity) => {
            const Icon = activity.icon
            return (
              <div key={activity.id} className="flex items-center gap-4">
                <Avatar className="h-9 w-9">
                  <AvatarFallback className="bg-muted">
                    <Icon className="h-4 w-4" />
                  </AvatarFallback>
                </Avatar>
                <div className="flex-1 space-y-1">
                  <p className="text-sm font-medium leading-none">
                    {activity.user} <span className="text-muted-foreground font-normal">{activity.action}</span>
                  </p>
                  <p className="text-xs text-muted-foreground">{activity.time}</p>
                </div>
                <Badge variant="secondary" className="text-xs">
                  {activity.badge}
                </Badge>
              </div>
            )
          })}
        </div>
      </CardContent>
    </Card>
  )
}
