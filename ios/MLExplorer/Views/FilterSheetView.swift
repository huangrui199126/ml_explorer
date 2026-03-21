import SwiftUI

struct FilterSheetView: View {
    @ObservedObject var vm: PapersViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    Picker("Topic", selection: $vm.selectedTopic) {
                        ForEach(vm.allTopics, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                Section("Company") {
                    Picker("Company", selection: $vm.selectedCompany) {
                        ForEach(vm.allCompanies, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Button("Reset Filters", role: .destructive) {
                        vm.resetFilters()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
