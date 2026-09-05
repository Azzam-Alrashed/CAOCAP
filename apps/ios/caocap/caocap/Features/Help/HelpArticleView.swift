import SwiftUI

struct HelpArticleView: View {
    let article: HelpArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(article.bodyParagraphKeys, id: \.self) { key in
                    Text(LocalizationManager.shared.localizedString(key))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(LocalizationManager.shared.localizedString(article.titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}
