import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            Group {
                switch auth.stage {
                case .phone:
                    PhoneNumberView()
                case .code:
                    VerificationCodeView()
                case .profile:
                    AccountProfileView()
                case .signedIn:
                    EmptyView()
                }
            }
            .animation(.default, value: auth.stage)
        }
    }
}

struct PhoneNumberView: View {
    @EnvironmentObject private var auth: AuthStore
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome")
                    .font(.system(size: 38, weight: .bold, design: .rounded))

                Text("Create your account with your phone number.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Phone number")
                    .font(.headline)

                HStack {
                    Text("+1")
                        .foregroundStyle(.secondary)

                    TextField("(555) 555-1234", text: $auth.phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focused)
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await auth.sendCode() }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!auth.canSendCode || auth.isLoading)

            Text("We’ll text you a verification code. Message and data rates may apply.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
        .padding(24)
        .onAppear { focused = true }
    }
}

struct VerificationCodeView: View {
    @EnvironmentObject private var auth: AuthStore
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Check your texts")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("Enter the 6-digit code sent to \(auth.normalizedPhoneNumber).")
                    .foregroundStyle(.secondary)
            }

            TextField("123456", text: $auth.verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                .tracking(10)
                .multilineTextAlignment(.center)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                .focused($focused)
                .onChange(of: auth.verificationCode) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(6))
                    if digits != newValue {
                        auth.verificationCode = digits
                    }
                }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await auth.verifyCode() }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Verify")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!auth.canVerifyCode || auth.isLoading)

            Button("Use a different phone number") {
                auth.verificationCode = ""
                auth.errorMessage = nil
                auth.stage = .phone
            }
            .frame(maxWidth: .infinity)

            #if DEBUG
            Text("Development code: 123456")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            #endif

            Spacer()
            Spacer()
        }
        .padding(24)
        .onAppear { focused = true }
    }
}

struct AccountProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Finish your account")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("Tell us who you are in the household.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Your name")
                    .font(.headline)

                TextField("Name", text: $auth.name)
                    .textContentType(.name)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                    .focused($focused)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Account type")
                    .font(.headline)

                Picker("Account type", selection: $auth.role) {
                    Text("Parent").tag(MemberRole.parent)
                    Text("Child").tag(MemberRole.child)
                }
                .pickerStyle(.segmented)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button {
                auth.finishProfile()
            } label: {
                Text("Create account")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
            Spacer()
        }
        .padding(24)
        .onAppear { focused = true }
    }
}
