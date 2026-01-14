"use client"

import { DollarSign, Users, FileCheck, AlertCircle } from "lucide-react"
import { AdminLayout } from "@/components/admin/admin-layout"
import { KPICard } from "@/components/admin/kpi-card"
import { ActivityChart } from "@/components/admin/activity-chart"
import { RecentActivity } from "@/components/admin/recent-activity"
import { AnalyticsWidget } from "@/components/admin/analytics-widget"
import { ActivityLog } from "@/components/admin/activity-log"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useLanguage } from "@/lib/language-context"

export default function DashboardPage() {
  const { t } = useLanguage()

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">{t("dashboard")}</h1>
          <p className="text-muted-foreground mt-1">{t("overviewOfOperations")}</p>
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <KPICard
            title={t("totalRevenue")}
            value="$45,231"
            change={12.5}
            icon={<DollarSign className="h-4 w-4" />}
            sparklineData={[2400, 2800, 2600, 3200, 2900, 3400, 3800, 4200]}
          />
          <KPICard
            title={t("activeUsers")}
            value="2,834"
            change={8.2}
            icon={<Users className="h-4 w-4" />}
            sparklineData={[1800, 2100, 2000, 2300, 2500, 2700, 2800, 2834]}
          />
          <KPICard
            title={t("pendingVerifications")}
            value="23"
            change={-5.4}
            icon={<FileCheck className="h-4 w-4" />}
            sparklineData={[45, 38, 42, 35, 28, 25, 24, 23]}
          />
          <KPICard
            title={t("openDisputes")}
            value="8"
            change={-12.3}
            icon={<AlertCircle className="h-4 w-4" />}
            sparklineData={[18, 15, 14, 12, 11, 10, 9, 8]}
          />
        </div>

        <AnalyticsWidget />

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-7">
          <div className="lg:col-span-4">
            <ActivityChart />
          </div>
          <div className="lg:col-span-3">
            <RecentActivity />
          </div>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>{t("activityLog")}</CardTitle>
            <CardDescription>{t("recentActions")}</CardDescription>
          </CardHeader>
          <CardContent>
            <Tabs defaultValue="all" className="w-full">
              <TabsList>
                <TabsTrigger value="all">{t("allActivity")}</TabsTrigger>
                <TabsTrigger value="today">{t("today")}</TabsTrigger>
                <TabsTrigger value="week">{t("thisWeek")}</TabsTrigger>
              </TabsList>
              <TabsContent value="all" className="mt-4">
                <ActivityLog />
              </TabsContent>
              <TabsContent value="today" className="mt-4">
                <ActivityLog />
              </TabsContent>
              <TabsContent value="week" className="mt-4">
                <ActivityLog />
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </div>
    </AdminLayout>
  )
}
