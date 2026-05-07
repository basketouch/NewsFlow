import SwiftUI

struct SocialPostsCalendarView: View {
    @ObservedObject var viewModel: SocialPostsViewModel
    @State private var currentDate = Date()
    @State private var selectedPost: SocialPost?
    @State private var showingPostDetail = false

    private let calendar = Calendar.current
    private let daysOfWeek = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Calendario en la parte superior
                header
                daysOfWeekHeader
                calendarGrid
                Divider().padding(.vertical, 8)
                // Lista de próximas publicaciones
                VStack(alignment: .leading, spacing: 0) {
                    Text("Próximas publicaciones")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    ForEach(upcomingPosts) { post in
                        Button(action: {
                            selectedPost = post
                            showingPostDetail = true
                        }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(circleColor(for: post.redSocialEnum))
                                        .frame(width: 28, height: 28)
                                    Text(circleLetter(for: post.redSocialEnum))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(post.textoEnriquecido.isEmpty ? post.texto : post.textoEnriquecido)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                        .foregroundColor(.primary)
                                    Text(post.formattedPublishDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Divider().padding(.leading, 44)
                    }
                    if upcomingPosts.isEmpty {
                        Text("No hay publicaciones próximas.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPostDetail) {
            if let post = selectedPost {
                SocialPostDetailView(post: post, viewModel: viewModel)
            }
        }
        .navigationTitle("Calendario")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthYearString(for: currentDate))
                .font(.headline)
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private var daysOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \ .self) { day in
                Text(day)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 2)
    }

    private var calendarGrid: some View {
        let days = generateDaysInMonth(for: currentDate)
        return VStack(spacing: 0) {
            ForEach(0..<days.count/7, id: \ .self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \ .self) { dayIndex in
                        let day = days[weekIndex * 7 + dayIndex]
                        DayCell(day: day, posts: posts(for: day.date), viewModel: viewModel, selectedPost: $selectedPost, showingPostDetail: $showingPostDetail)
                    }
                }
            }
        }
    }

    // MARK: - Funciones auxiliares

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }

    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentDate) {
            currentDate = newDate
        }
    }

    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentDate) {
            currentDate = newDate
        }
    }

    private func posts(for date: Date) -> [SocialPost] {
        viewModel.posts.filter { calendar.isDate($0.fecha, inSameDayAs: date) }
    }

    private var upcomingPosts: [SocialPost] {
        viewModel.posts.filter { !$0.publicado && $0.fecha >= Date().startOfDay }
            .sorted { $0.fecha < $1.fecha }
    }

    private func circleLetter(for network: SocialNetwork) -> String {
        switch network {
        case .linkedin:
            return "L"
        case .twitter:
            return "X"
        }
    }

    private func circleColor(for network: SocialNetwork) -> Color {
        switch network {
        case .linkedin:
            return .blue
        case .twitter:
            return .cyan
        }
    }

    struct Day {
        let date: Date
        let number: String
        let isCurrentMonth: Bool
        let isToday: Bool
    }

    private func generateDaysInMonth(for date: Date) -> [Day] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        var days: [Day] = []
        var current = firstWeek.start
        while current < monthInterval.end || calendar.isDate(current, inSameDayAs: monthInterval.end) {
            let isCurrentMonth = calendar.isDate(current, equalTo: date, toGranularity: .month)
            let isToday = calendar.isDateInToday(current)
            let number = String(calendar.component(.day, from: current))
            days.append(Day(date: current, number: number, isCurrentMonth: isCurrentMonth, isToday: isToday))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        // Ajustar para que siempre sean múltiplos de 7 (semana completa)
        while days.count % 7 != 0 {
            let lastDate = days.last!.date
            let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate)!
            let isCurrentMonth = calendar.isDate(nextDate, equalTo: date, toGranularity: .month)
            let isToday = calendar.isDateInToday(nextDate)
            let number = String(calendar.component(.day, from: nextDate))
            days.append(Day(date: nextDate, number: number, isCurrentMonth: isCurrentMonth, isToday: isToday))
        }
        return days
    }
}

private struct DayCell: View {
    let day: SocialPostsCalendarView.Day
    let posts: [SocialPost]
    let viewModel: SocialPostsViewModel
    @Binding var selectedPost: SocialPost?
    @Binding var showingPostDetail: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(day.number)
                .font(.caption)
                .foregroundColor(day.isCurrentMonth ? .primary : .secondary)
            HStack(spacing: 2) {
                ForEach(posts, id: \ .id) { post in
                    Button(action: {
                        selectedPost = post
                        showingPostDetail = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(circleColor(for: post.redSocialEnum))
                                .frame(width: 20, height: 20)
                            Text(circleLetter(for: post.redSocialEnum))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(day.isToday ? Color.yellow.opacity(0.25) : Color.clear)
        .cornerRadius(6)
    }

    private func circleLetter(for network: SocialNetwork) -> String {
        switch network {
        case .linkedin:
            return "L"
        case .twitter:
            return "X"
        }
    }

    private func circleColor(for network: SocialNetwork) -> Color {
        switch network {
        case .linkedin:
            return .blue
        case .twitter:
            return .cyan
        }
    }
}

// Extensión para obtener el inicio del día
extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
} 