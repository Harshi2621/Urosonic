// PatientMessagesView.swift — Live chat threads with doctor & patient
// Aura MedTech Design System — Real-Time Messaging & Read Receipts

import SwiftUI

// MARK: - PatientMessagesView
struct PatientMessagesView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState

    @State private var activeChat:    Int? = nil
    @State private var inputText      = ""
    @State private var conversations: [APIConversation] = []
    @State private var messages:      [APIChatMessage]  = []
    @State private var appeared       = false
    @State private var isLoadingConvs = true

    var body: some View {
        Group {
            if let chatUserId = activeChat {
                let activeConv = conversations.first(where: { $0.userId == chatUserId })
                let docRaw = activeConv?.name ?? "Dr. Specialist"
                ChatRoomView(
                    chatName: docRaw.formattedDoctorTitle,
                    subtitle: "Attending Urologist • Doctor ID #\(chatUserId)",
                    bubbleColor: Color.appTeal,
                    partnerId: chatUserId,
                    partnerRole: activeConv?.role ?? "doctor",
                    messages: messages,
                    inputText: $inputText,
                    onBack: {
                        activeChat = nil
                        Task { await loadConversations() }
                    },
                    onSend: { Task { await sendMessage(to: chatUserId) } },
                    onReload: { await loadThread(with: chatUserId) }
                )
                .onAppear { Task { await loadThread(with: chatUserId) } }
            } else {
                ConversationListView(
                    title: "Clinical Messages",
                    subtitle: "Direct consultations with your care team",
                    currentUserId: authState.userId,
                    isLoading: isLoadingConvs,
                    conversations: conversations,
                    onSelect: {
                        messages = []
                        activeChat = $0
                    },
                    onReload: { await loadConversations() }
                )
                .onAppear { Task { await loadConversations() } }
                .refreshable { await loadConversations() }
            }
        }
        .onChange(of: router.patientTab) {
            activeChat = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetPatientMessagesToRoot)) { _ in
            activeChat = nil
        }
    }

    private func loadConversations() async {
        isLoadingConvs = true
        conversations  = (try? await APIClient.shared.getConversations(userId: authState.userId)) ?? []
        isLoadingConvs = false
    }

    private func loadThread(with partnerId: Int) async {
        if let fetched = try? await APIClient.shared.getThread(userA: authState.userId, userB: partnerId) {
            messages = fetched
        }
    }

    private func sendMessage(to partnerId: Int) async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = inputText
        inputText = ""
        if let sent = try? await APIClient.shared.sendMessage(senderId: authState.userId, receiverId: partnerId, text: text) {
            withAnimation(.spring(response: 0.3)) {
                messages.append(sent)
            }
        }
    }
}

// MARK: - Doctor Title Formatter
extension String {
    var formattedDoctorTitle: String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Dr. Specialist" }
        if trimmed.lowercased().hasPrefix("dr.") {
            let withoutPrefix = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            return "Dr. \(withoutPrefix.capitalized)"
        } else if trimmed.lowercased().hasPrefix("dr ") {
            let withoutPrefix = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            return "Dr. \(withoutPrefix.capitalized)"
        }
        return "Dr. \(trimmed.capitalized)"
    }
}

// MARK: - DoctorMessagesView
struct DoctorMessagesView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState

    @State private var activeChat:    Int? = nil
    @State private var inputText      = ""
    @State private var conversations: [APIConversation] = []
    @State private var patients:      [APIPatientListItem] = []
    @State private var messages:      [APIChatMessage]  = []
    @State private var appeared       = false
    @State private var isLoadingConvs = true

    var body: some View {
        Group {
            if let chatUserId = activeChat {
                let activeConv = conversations.first(where: { $0.userId == chatUserId })
                let patientObj = patients.first(where: { $0.id == chatUserId })
                let rawName = activeConv?.name ?? patientObj?.name ?? "Patient #\(chatUserId)"
                let doctorName = authState.fullName.formattedDoctorTitle
                ChatRoomView(
                    chatName: rawName.capitalized,
                    subtitle: "Patient ID #\(chatUserId) • \(doctorName)",
                    bubbleColor: Color.appBlue,
                    partnerId: chatUserId,
                    partnerRole: activeConv?.role ?? "patient",
                    messages: messages,
                    inputText: $inputText,
                    onBack: {
                        activeChat = nil
                        Task { await loadConversations() }
                    },
                    onSend: { Task { await sendMessage(to: chatUserId) } },
                    onReload: { await loadThread(with: chatUserId) }
                )
                .onAppear { Task { await loadThread(with: chatUserId) } }
            } else {
                ConversationListView(
                    title: "Patient Consultations",
                    subtitle: "Active patient communication threads",
                    currentUserId: authState.userId,
                    isLoading: isLoadingConvs,
                    conversations: conversations,
                    onSelect: {
                        messages = []
                        activeChat = $0
                    },
                    onReload: { await loadConversations() }
                )
                .onAppear { Task { await loadConversations() } }
                .refreshable { await loadConversations() }
            }
        }
        .onAppear {
            if let target = router.activeDoctorChatUserId {
                activeChat = target
                router.activeDoctorChatUserId = nil
            }
        }
        .onChange(of: router.activeDoctorChatUserId) {
            if let target = router.activeDoctorChatUserId {
                activeChat = target
                router.activeDoctorChatUserId = nil
            }
        }
        .onChange(of: router.doctorTab) {
            activeChat = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetDoctorMessagesToRoot)) { _ in
            activeChat = nil
        }
    }

    private func loadConversations() async {
        isLoadingConvs = true
        async let convs = try? APIClient.shared.getConversations(userId: authState.userId)
        async let pts   = try? APIClient.shared.getDoctorPatients(doctorId: authState.userId)
        conversations = await convs ?? []
        patients = await pts ?? []
        isLoadingConvs = false
    }

    private func loadThread(with partnerId: Int) async {
        if let fetched = try? await APIClient.shared.getThread(userA: authState.userId, userB: partnerId) {
            messages = fetched
        }
    }

    private func sendMessage(to partnerId: Int) async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = inputText
        inputText = ""
        if let sent = try? await APIClient.shared.sendMessage(senderId: authState.userId, receiverId: partnerId, text: text) {
            withAnimation(.spring(response: 0.3)) {
                messages.append(sent)
            }
        }
    }
}

// MARK: - Message Status Tick View (Reached, Read Blue, Unread)
struct MessageTickView: View {
    let isRead: Bool
    var isDelivered: Bool = true
    var customColor: Color? = nil

    private var blueColor: Color {
        Color.dynamic(light: "0284C7", dark: "38BDF8")
    }

    private var grayColor: Color {
        Color.dynamic(light: "94A3B8", dark: "64748B")
    }

    var body: some View {
        HStack(spacing: -3.5) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            if isDelivered {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundColor(customColor ?? (isRead ? blueColor : grayColor))
        .accessibilityLabel(isRead ? "Read" : "Reached / Delivered")
    }
}

// MARK: - Shared Conversation List View
struct ConversationListView: View {
    let title: String
    var subtitle: String? = nil
    let currentUserId: Int
    let isLoading: Bool
    let conversations: [APIConversation]
    let onSelect: (Int) -> Void
    var onReload: (() async -> Void)? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)

                        if let sub = subtitle {
                            Text(sub)
                                .font(.system(size: 12))
                                .foregroundColor(Color.slateSub)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)

                if isLoading && conversations.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView().tint(Color.appTeal)
                        Spacer()
                    }
                } else if conversations.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.appTeal.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Image(systemName: "message.fill")
                                .font(.system(size: 30))
                                .foregroundColor(Color.appTeal)
                        }
                        Text("No conversations yet")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slateText)
                        Text("When you or your physician send messages, they will appear here.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.slateSub)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(conversations) { chat in
                                Button {
                                    onSelect(chat.userId)
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack(alignment: .topTrailing) {
                                            AvatarView(
                                                initials: chat.avatar,
                                                size: 50,
                                                bg: chat.role == "doctor" ? Color.appTeal.opacity(0.12) : Color.appBlue.opacity(0.12),
                                                fg: chat.role == "doctor" ? Color.appTeal : Color.appBlue
                                            )

                                            if chat.unreadCount > 0 {
                                                Circle()
                                                    .fill(Color.appCyanLight)
                                                    .frame(width: 10, height: 10)
                                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                    .offset(x: 2, y: -2)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(chat.name)
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.slateText)

                                                if chat.role == "doctor" {
                                                    Text("SPECIALIST")
                                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                                        .foregroundColor(Color.appTeal)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.appTeal.opacity(0.1))
                                                        .clipShape(Capsule())
                                                }

                                                Spacer()
                                                Text(shortTime(chat.lastTime))
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(chat.unreadCount > 0 ? Color.appTeal : Color.slateSub)
                                            }

                                            HStack(spacing: 4) {
                                                // Show delivery/read tick if last message was sent by the current user
                                                if chat.lastSenderId == currentUserId {
                                                    MessageTickView(isRead: chat.lastIsRead ?? false)
                                                }

                                                Text(chat.lastMessage ?? "Start consultation...")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(chat.unreadCount > 0 ? Color.slateText : Color.slateSub)
                                                    .fontWeight(chat.unreadCount > 0 ? .semibold : .regular)
                                                    .lineLimit(1)
                                            }
                                        }

                                        if chat.unreadCount > 0 {
                                            Circle()
                                                .fill(Color.appTeal)
                                                .frame(width: 22, height: 22)
                                                .overlay(
                                                    Text("\(chat.unreadCount)")
                                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                                        .foregroundColor(.white)
                                                )
                                                .shadow(color: Color.appTeal.opacity(0.3), radius: 4, y: 1)
                                        }
                                    }
                                    .padding(14)
                                    .uroCard(cornerRadius: 18)
                                }
                                .tactileButton()
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await onReload?()
            }
        }
    }

    private func shortTime(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let d = f.date(from: dateStr) else { return dateStr }
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: d)
    }
}

// MARK: - Shared Chat Room View
struct ChatRoomView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    let chatName: String
    let subtitle: String
    let bubbleColor: Color
    let partnerId: Int
    let partnerRole: String
    let messages: [APIChatMessage]
    @Binding var inputText: String
    let onBack: () -> Void
    let onSend: () -> Void
    var onReload: (() async -> Void)? = nil

    @State private var partnerUser: APIUser? = nil
    @State private var attendingDoctorName: String? = nil

    private var displayTitle: String {
        if let p = partnerUser {
            if p.role == "doctor" {
                return p.fullName.formattedDoctorTitle
            } else {
                return p.fullName.capitalized
            }
        }
        if !chatName.isEmpty && chatName != "Patient" && chatName != "Dr. Specialist" {
            if partnerRole == "doctor" {
                return chatName.formattedDoctorTitle
            }
            return chatName.capitalized
        }
        if partnerRole == "doctor" {
            return attendingDoctorName ?? "Dr. Specialist"
        }
        return "Patient #\(partnerId)"
    }

    private var displaySubtitle: String {
        let isPartnerPatient = (partnerUser?.role == "patient") || (partnerRole == "patient")
        if isPartnerPatient {
            let docStr: String = {
                if let doc = attendingDoctorName {
                    return doc
                }
                if authState.isDoctor {
                    return authState.fullName.formattedDoctorTitle
                }
                return ""
            }()
            if !docStr.isEmpty {
                return "Patient ID #\(partnerId) • \(docStr)"
            } else {
                return "Patient ID #\(partnerId)"
            }
        } else {
            let spec = partnerUser?.specialization ?? "Attending Urologist"
            return "\(spec) • Doctor ID #\(partnerId)"
        }
    }

    private var displayInitials: String {
        if let p = partnerUser {
            return p.initials
        }
        let clean = displayTitle.replacingOccurrences(of: "Dr. ", with: "").replacingOccurrences(of: "Dr ", with: "")
        let firstLetter = clean.prefix(1).uppercased()
        return firstLetter.isEmpty ? "U" : firstLetter
    }

    var body: some View {
        ZStack {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Chat Header Bar
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        ZStack {
                            Circle()
                                .fill(Color.slateCard)
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.slateText)
                        }
                    }
                    .tactileButton()

                    AvatarView(
                        initials: displayInitials,
                        size: 38,
                        bg: bubbleColor.opacity(0.15),
                        fg: bubbleColor
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(displayTitle)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slateText)

                            if (partnerUser?.role == "doctor") || (partnerRole == "doctor") {
                                Text("SPECIALIST")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.appTeal)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.appTeal.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(displaySubtitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(bubbleColor)
                    }

                    Spacer()

                    // Legend status chip
                    HStack(spacing: 4) {
                        MessageTickView(isRead: true)
                        Text("Read Receipts")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color.slateSub)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.slateLight.opacity(0.8))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)

                // Message Thread with Auto-Scroll to Bottom
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(messages, id: \.id) { msg in
                                ChatMessageItemView(
                                    msg: msg,
                                    bubbleColor: bubbleColor,
                                    partnerId: partnerId,
                                    partnerRole: partnerRole
                                )
                                .id(msg.id)
                            }

                            // Bottom scroll anchor
                            Color.clear
                                .frame(height: 1)
                                .id("BOTTOM_ANCHOR")
                        }
                        .padding(.vertical, 16)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                    }
                    .onChange(of: messages.count) {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                    .onChange(of: messages.last?.id) {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }

                // Composer Bar
                HStack(spacing: 10) {
                    TextField("Write a message...", text: $inputText)
                        .font(.system(size: 14))
                        .foregroundColor(Color.slateText)
                        .padding(.horizontal, 16)
                        .frame(height: 46)
                        .background(Color.slateCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.slateBorder, lineWidth: 1))

                    Button(action: onSend) {
                        ZStack {
                            Circle()
                                .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.slateLight : bubbleColor)
                                .frame(width: 44, height: 44)
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.slateMuted : .white)
                        }
                    }
                    .tactileButton()
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            Task { await resolvePartner() }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await onReload?()
            }
        }
    }

    private func resolvePartner() async {
        if let u = try? await APIClient.shared.getProfile(userId: partnerId) {
            await MainActor.run {
                self.partnerUser = u
            }
            if u.role == "patient" {
                if let docId = u.doctorId, docId > 0 {
                    if let docUser = try? await APIClient.shared.getProfile(userId: docId) {
                        await MainActor.run {
                            self.attendingDoctorName = docUser.fullName.formattedDoctorTitle
                        }
                    }
                } else if authState.isDoctor {
                    await MainActor.run {
                        self.attendingDoctorName = authState.fullName.formattedDoctorTitle
                    }
                }
            }
        }
        if attendingDoctorName == nil && authState.isDoctor {
            await MainActor.run {
                self.attendingDoctorName = authState.fullName.formattedDoctorTitle
            }
        }
        if partnerRole == "doctor" && (partnerUser == nil || attendingDoctorName == nil) {
            if let docs = try? await APIClient.shared.getDoctors() {
                if let matched = docs.first(where: { $0.id == partnerId }) {
                    await MainActor.run {
                        self.attendingDoctorName = matched.fullName.formattedDoctorTitle
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
        guard !messages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
        }
    }
}

// MARK: - Clinical Report Card Bubble
struct ClinicalReportCardBubble: View {
    let messageText: String
    let isMe: Bool
    let isRead: Bool
    let sentAt: String?
    let partnerId: Int
    let partnerRole: String
    let onInspect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.appTeal.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appTeal)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Clinical Uroflow Telemetry")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                    Text("Acoustic AI Test Record")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.slateSub)
                }

                Spacer()

                StatusBadgeView(status: extractStatus(from: messageText))
            }

            Divider()

            Text(cleanedTelemetryText(from: messageText))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color.slateText)
                .lineSpacing(3)

            Button(action: onInspect) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 12, weight: .bold))
                    Text("Inspect Interactive Graph & Telemetry")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(LinearGradient(colors: [Color.appTeal, Color(hex: "0F766E")], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(10)
                .shadow(color: Color.appTeal.opacity(0.25), radius: 4, y: 2)
            }
            .tactileButton()

            // Timestamp + Delivery / Read Receipt
            HStack(spacing: 4) {
                Spacer()
                Text(shortTime(sentAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.slateSub)

                if isMe {
                    MessageTickView(isRead: isRead)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color.slateCard)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.appTeal.opacity(0.3), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        .frame(maxWidth: 300, alignment: isMe ? .trailing : .leading)
    }

    private func extractStatus(from text: String) -> String {
        if text.contains("ABNORMAL") { return "ABNORMAL" }
        if text.contains("BORDERLINE") { return "BORDERLINE" }
        return "NORMAL"
    }

    private func cleanedTelemetryText(from text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            line.contains("•") || line.contains("Record") || line.contains("Qmax") || line.contains("Volume") || line.contains("Duration")
        }
        return filtered.isEmpty ? text : filtered.joined(separator: "\n")
    }

    private func shortTime(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let d = f.date(from: dateStr) else { return dateStr }
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: d)
    }
}

// MARK: - Chat Message Item View
struct ChatMessageItemView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    let msg: APIChatMessage
    let bubbleColor: Color
    let partnerId: Int
    let partnerRole: String

    var isMe: Bool {
        msg.senderId == authState.userId
    }

    var isReport: Bool {
        msg.message.contains("CLINICAL UROFLOWMETRY REPORT") || msg.message.contains("Qmax:")
    }

    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
            if isReport {
                ClinicalReportCardBubble(
                    messageText: msg.message,
                    isMe: isMe,
                    isRead: msg.isRead,
                    sentAt: msg.sentAt,
                    partnerId: partnerId,
                    partnerRole: partnerRole,
                    onInspect: {
                        if authState.currentUser?.role == "doctor" {
                            router.openPatientDetail(id: String(partnerId))
                        } else {
                            router.showResultFromHistory()
                        }
                    }
                )
            } else {
                VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                    Text(msg.message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isMe ? .white : Color.slateText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            isMe ?
                                LinearGradient(colors: [bubbleColor, bubbleColor.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.slateCard, Color.slateCard], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            !isMe ? RoundedRectangle(cornerRadius: 18).stroke(Color.slateBorder, lineWidth: 0.8) : nil
                        )
                        .shadow(color: isMe ? bubbleColor.opacity(0.2) : Color.black.opacity(0.03), radius: 6, y: 2)

                    // Footer with timestamp and Reached / Read (Blue) Ticks
                    HStack(spacing: 4) {
                        Text(shortTime(msg.sentAt))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.slateSub)

                        if isMe {
                            MessageTickView(isRead: msg.isRead)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: 280, alignment: isMe ? .trailing : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
        .padding(.horizontal, 16)
    }

    private func shortTime(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let d = f.date(from: dateStr) else { return dateStr }
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: d)
    }
}
