//
//  Step.swift
//  traverse
//

import SwiftUI

struct Step: View {
    let icon: String
    let gradient: (Color, Color, Color)
    let title: String
    let description: String
    
    var isExpanded: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    var iconColour: Color {
        colorScheme == .dark ? gradient.2 : gradient.0
    }
    
    var body: some View {
        let layout = isExpanded
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 24))
        
        layout {
            Group {
                Image(systemName: icon)
                    .font(.system(size: isExpanded ? 32 : 20))
                    .bold()
                    .foregroundStyle(isExpanded ? iconColour : .secondary)
                
                Text(title)
                    .font(.system(size: isExpanded ? 42 : 24))
                    .bold()
                    .foregroundStyle(isExpanded ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .drawingGroup()
            
            if isExpanded {
                Text(description)
                    .foregroundStyle(Color.primary.opacity(0.3))
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
