import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                Group {
                    switch auth.stage {
                    case .email:
                        EmailAddressView()
                    case .code:
                        VerificationCodeView()
                    case .profile:
                        AccountProfileView()
                    case .signedIn:
                        EmptyView()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
            .animation(.snappy(duration: 0.28), value: auth.stage)
        }
    }
}

struct AuthHeader: View {
    let step: Int
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: symbol)
                    .font(.title2.bold())
                    .foregroundStyle(.indigo)
                    .frame(width: 52, height: 52)
                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))

                Spacer()

                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { item in
                        Capsule()
                            .fill(item <= step ? Color.indigo : Color.secondary.opacity(0.18))
                            .frame(width: item == step ? 26 : 8, height: 8)
                            .animation(.snappy, value: step)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 35, weight: .bold, design: .rounded))

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let loading: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(loading ? 0 : 1)

                if loading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(disabled ? Color.secondary.opacity(0.4) : Color.indigo, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(disabled)
    }
}

struct AuthErrorView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct EmailAddressView: View {
    @EnvironmentObject private var auth: AuthStore
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                AuthHeader(
                    step: 1,
                    title: "Let’s get you signed in",
                    subtitle: "Use one New Life Media account across your apps.",
                    symbol: "person.crop.circle.badge.checkmark"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Email")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.secondary)

                        TextField("you@example.com", text: $auth.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .submitLabel(.continue)
                            .onSubmit {
                                if auth.canSendCode && !auth.isLoading {
                                    Task { await auth.sendCode() }
                                }
                            }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 17))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(focused ? Color.indigo.opacity(0.55) : Color.secondary.opacity(0.12), lineWidth: focused ? 1.5 : 1)
                    )
                    .animation(.snappy, value: focused)

                    Text("We’ll email you a 6-digit code. No password to remember.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = auth.errorMessage {
                    AuthErrorView(message: error)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                AuthPrimaryButton(
                    title: "Email me a code",
                    loading: auth.isLoading,
                    disabled: !auth.canSendCode || auth.isLoading
                ) {
                    Task { await auth.sendCode() }
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                    Text("Your sign-in code expires quickly and can only be used once.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .padding(.top, 26)
        }
        .onAppear { focused = true }
    }
}

struct VerificationCodeView: View {
    @EnvironmentObject private var auth: AuthStore
    @FocusState private var focused: Bool
    @State private var feedback = 0

    private var digits: [Character] {
        Array(auth.verificationCode.padding(toLength: 6, withPad: " ", startingAt: 0))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                AuthHeader(
                    step: 2,
                    title: "Check your email",
                    subtitle: "We sent a code to \(auth.normalizedEmail).",
                    symbol: "envelope.open.fill"
                )

                ZStack {
                    HStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { index in
                            Text(index < auth.verificationCode.count ? String(Array(auth.verificationCode)[index]) : "")
                                .font(.title2.bold().monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(.background, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(index == auth.verificationCode.count && focused ? Color.indigo : Color.secondary.opacity(0.12), lineWidth: 1.5)
                                )
                        }
                    }

                    TextField("", text: $auth.verificationCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focused)
                        .opacity(0.01)
                        .onChange(of: auth.verificationCode) { _, newValue in
                            let clean = String(newValue.filter(\.isNumber).prefix(6))
                            if clean != newValue {
                                auth.verificationCode = clean
                            }

                            if clean.count == 6 {
                                feedback += 1
                            }
                        }
                }
                .contentShape(Rectangle())
                .onTapGesture { focused = true }

                if let error = auth.errorMessage {
                    AuthErrorView(message: error)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                AuthPrimaryButton(
                    title: "Verify code",
                    loading: auth.isLoading,
                    disabled: !auth.canVerifyCode || auth.isLoading
                ) {
                    Task { await auth.verifyCode() }
                }

                Button {
                    auth.verificationCode = ""
                    auth.errorMessage = nil
                    auth.stage = .email
                } label: {
                    Label("Use a different email", systemImage: "arrow.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(SoftPressStyle())

                Text("Didn’t get it? You can go back and request another code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .padding(.top, 26)
        }
        .onAppear { focused = true }
        .sensoryFeedback(.selection, trigger: feedback)
    }
}

struct AccountProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @FocusState private var focused: Bool
    @State private var feedback = 0

    private var canContinue: Bool {
        !auth.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                AuthHeader(
                    step: 3,
                    title: "Finish your account",
                    subtitle: "This name follows your New Life Media account across apps.",
                    symbol: "person.fill.checkmark"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)

                        TextField("Name", text: $auth.name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .focused($focused)
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 17))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(focused ? Color.indigo.opacity(0.55) : Color.secondary.opacity(0.12), lineWidth: focused ? 1.5 : 1)
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("For this prototype")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        roleButton("Parent", symbol: "person.2.fill", role: .parent)
                        roleButton("Child", symbol: "figure.child", role: .child)
                    }

                    Text("This will move into household setup later instead of being part of your global account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = auth.errorMessage {
                    AuthErrorView(message: error)
                }

                AuthPrimaryButton(
                    title: "Create account",
                    loading: false,
                    disabled: !canContinue
                ) {
                    feedback += 1
                    auth.finishProfile()
                }
            }
            .padding(24)
            .padding(.top, 26)
        }
        .onAppear { focused = true }
        .sensoryFeedback(.success, trigger: feedback)
    }

    private func roleButton(_ title: String, symbol: String, role: MemberRole) -> some View {
        let selected = auth.role == role

        return Button {
            auth.role = role
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(selected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? Color.indigo : Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(SoftPressStyle())
    }
}
