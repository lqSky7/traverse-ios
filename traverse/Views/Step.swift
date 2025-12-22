//
//  Step.swift
//  traverse
//

import SwiftUI

struct Step: View {
    let icon: String
    let iconColour: Color
    let title: String
    let description: String
    
    var isExpanded: Bool
    
    var body: some View {
        let layout = isExpanded
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 24))
        
        layout {
            Group {
                Image(systemName: icon)
                    .font(.system(size: isExpanded ? 32 : 20))
                    .bold()
                    .foregroundStyle(isExpanded ? iconColour : .gray)
                
                Text(title)
                    .font(.system(size: isExpanded ? 42 : 24))
                    .bold()
                    .foregroundStyle(isExpanded ? .black : .gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .drawingGroup()
            
            if isExpanded {
                Text(description)
                    .foregroundStyle(.black.opacity(0.3))
                    .fontWeight(.medium)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 30).combined(with: .opacity),
                            removal: .offset(y: -60).combined(with: .opacity)
                        )
                        .animation(.smooth(duration: 0.2))
                    )
            }
        }
    }
}
