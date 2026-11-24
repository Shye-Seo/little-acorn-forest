import SwiftUI
import AcornForestCore

/// 숲 일기장(도감). 레시피·이웃의 기억·이야기·축제가 칸칸이 쌓인다.
struct DiaryView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selectedKind: DiaryKind?

    var body: some View {
        VStack(spacing: 8) {
            header
            kindPicker
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(entries) { entry in
                        entryCard(entry)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 6)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.closeDiary()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ForestPalette.sage)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(ForestPalette.parchment.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("숲 일기장")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text(store.showsExpandedDiary
                     ? "\(store.diaryEntriesUnlocked)/\(ForestDiary.totalCount) 칸 · 확장 \(store.expandedDiaryUnlocked)/\(store.expandedDiaryTotal)"
                     : "\(store.diaryEntriesUnlocked) / \(ForestDiary.totalCount) 칸")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            ProgressBar(value: Double(store.diaryEntriesUnlocked) / Double(max(1, ForestDiary.totalCount)), tint: ForestPalette.terracotta)
                .frame(width: 90)
        }
        .padding(.horizontal, 16)
    }

    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "전체", active: selectedKind == nil) {
                    selectedKind = nil
                }
                ForEach(DiaryKind.allCases) { kind in
                    chip(title: kind.title, active: selectedKind == kind) {
                        selectedKind = kind
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 2)
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.label(12))
                .foregroundStyle(active ? ForestPalette.parchment : ForestPalette.inkSoft)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(active ? ForestPalette.sage : ForestPalette.parchmentDeep.opacity(0.7)))
        }
        .buttonStyle(.plain)
    }

    private var entries: [DiaryEntry] {
        let base = selectedKind == nil ? ForestDiary.entries : ForestDiary.entries(kind: selectedKind!)
        guard store.showsExpandedDiary else { return base }
        let extras = selectedKind == nil
            ? ForestDiary.expandedEntries
            : ForestDiary.expandedEntries.filter { $0.kind == selectedKind }
        return base + extras
    }

    private func entryCard(_ entry: DiaryEntry) -> some View {
        let unlocked = store.state.hasDiary(entry.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: unlocked ? symbol(for: entry.kind) : "lock")
                    .font(.system(size: 11))
                    .foregroundStyle(unlocked ? ForestPalette.sage : ForestPalette.inkSoft.opacity(0.5))
                Text(unlocked ? entry.title : "아직 비어 있는 페이지")
                    .font(.story(15, weight: .semibold))
                    .foregroundStyle(unlocked ? ForestPalette.ink : ForestPalette.inkSoft.opacity(0.7))
                Spacer()
                Text(entry.kind.title)
                    .font(.label(9))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            if unlocked {
                Text(entry.body)
                    .font(.story(13))
                    .lineSpacing(5)
                    .foregroundStyle(ForestPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("이야기를 더 걸으면 채워질 자리예요.")
                    .font(.story(12))
                    .foregroundStyle(ForestPalette.inkSoft.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ForestPalette.parchment.opacity(unlocked ? 0.95 : 0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ForestPalette.pageEdge, lineWidth: 1)
                )
        )
        .opacity(unlocked ? 1 : 0.8)
    }

    private func symbol(for kind: DiaryKind) -> String {
        switch kind {
        case .recipe: return "fork.knife"
        case .memory: return "heart.fill"
        case .chapter: return "book.closed.fill"
        case .festival: return "sparkles"
        }
    }
}
