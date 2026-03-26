import SwiftUI

struct PoemFormPicker: View {
    @ObservedObject var vm: LyricViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PoemForm.allCases, id: \.self) { form in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            if vm.currentPoemForm == form {
                                vm.selectPoemForm(nil)
                            } else {
                                vm.selectPoemForm(form)
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(form.displayName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(form.description)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(vm.currentPoemForm == form
                                      ? Color.orange.opacity(0.15)
                                      : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(vm.currentPoemForm == form
                                              ? Color.orange.opacity(0.3)
                                              : Color.clear, lineWidth: 1)
                        )
                        .foregroundColor(vm.currentPoemForm == form
                                         ? .orange
                                         : .secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
