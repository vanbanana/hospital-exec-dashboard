import { use } from 'echarts/core'
import { BarChart, LineChart, PieChart, RadarChart, ScatterChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, LegendComponent, RadarComponent, MarkLineComponent, MarkPointComponent, MarkAreaComponent, TitleComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

use([BarChart, LineChart, PieChart, RadarChart, ScatterChart, GridComponent, TooltipComponent, LegendComponent, RadarComponent, MarkLineComponent, MarkPointComponent, MarkAreaComponent, TitleComponent, CanvasRenderer])
export { init, graphic } from 'echarts/core'
export type { ECharts, EChartsOption, SeriesOption } from 'echarts'
