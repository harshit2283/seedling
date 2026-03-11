package com.twotwoeightthreelabs.seedling

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/**
 * Android home screen widget provider for Seedling
 *
 * Displays tree state, entry count, and recent memories.
 * Supports small and medium widget sizes.
 */
class SeedlingWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget added to home screen for first time
    }

    override fun onDisabled(context: Context) {
        // Last widget removed from home screen
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Get widget data from shared preferences (set by home_widget package)
            val widgetData = HomeWidgetPlugin.getData(context)

            val treeEmoji = widgetData.getString("treeEmoji", "🌱") ?: "🌱"
            val entryCount = widgetData.getInt("entryCount", 0)
            val stateName = widgetData.getString("stateName", "Seed") ?: "Seed"
            val progress = widgetData.getFloat("progress", 0f)
            val stateDescription = widgetData.getString("stateDescription", "Every memory starts as a seed") ?: "Every memory starts as a seed"

            // Parse recent entries
            val recentEntriesJson = widgetData.getString("recentEntries", "[]") ?: "[]"
            val recentPreview = parseFirstEntryPreview(recentEntriesJson)

            // Determine widget size based on options
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)

            // Choose layout based on width (small: < 200dp, medium: >= 200dp)
            val layoutId = if (minWidth < 200) {
                R.layout.widget_small
            } else {
                R.layout.widget_medium
            }

            val views = RemoteViews(context.packageName, layoutId)

            // Set content for small widget
            if (layoutId == R.layout.widget_small) {
                views.setTextViewText(R.id.widget_tree_emoji, treeEmoji)
                views.setTextViewText(R.id.widget_entry_count, entryCount.toString())
            } else {
                // Set content for medium widget
                views.setTextViewText(R.id.widget_tree_emoji, treeEmoji)
                views.setTextViewText(R.id.widget_entry_count, entryCount.toString())
                views.setTextViewText(R.id.widget_state_name, stateName)

                // Progress bar (use percentage of width)
                val progressWidth = (progress * 100).toInt()
                views.setInt(R.id.widget_progress_bar, "setProgress", progressWidth)

                // Recent entry preview
                if (recentPreview.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_recent_preview, recentPreview)
                } else {
                    views.setTextViewText(R.id.widget_recent_preview, "Tap to add your first memory")
                }
            }

            // Set click intent to open app
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("seedling://home"))
            intent.setPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun parseFirstEntryPreview(jsonString: String): String {
            return try {
                val array = JSONArray(jsonString)
                if (array.length() > 0) {
                    val first = array.getJSONObject(0)
                    first.optString("preview", "")
                } else {
                    ""
                }
            } catch (e: Exception) {
                ""
            }
        }
    }
}
