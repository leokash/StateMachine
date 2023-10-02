//
//  Normal.swift
//  StateMachine
//
//  Created by Nkashama Kabeya on 01/10/2023.
//

import Foundation

enum Vanilla {
    struct StateMachine<S: State, E: Event> {
        private struct Transition: Hashable {
            let event: E
            let incoming: any State
            let outgoing: any State
            let callback: (() -> ())?
            
            func hash(into hasher: inout Hasher) {
                hasher.combine((event as any Hashable))
                hasher.combine((incoming as any Hashable))
                hasher.combine((incoming as any Hashable))
            }
            
            func matches(event: E, state: any State) -> Bool {
                self.event.hashValue == event.hashValue && self.incoming.hashValue == state.hashValue
            }
            
            static func == (lhs: Transition, rhs: Transition) -> Bool {
                lhs.event.hashValue == rhs.hashValue
                && lhs.incoming.hashValue == rhs.incoming.hashValue
                && rhs.outgoing.hashValue == rhs.outgoing.hashValue
            }
        }
        
        private var current: any State
        private var transitions: [AnyHashable: Set<Transition>] = [:]
        
        init(with state: S) {
            self.current = state
        }
        
        mutating func on(event: E) {
            let key = AnyHashable(event)
            if let transition = transitions[key]?.first(where: { $0.matches(event: event, state: current) }) {
                current = transition.outgoing
                transition.callback?()
            } else {
                print("***** no transition found for \(event) from \(current) *****")
            }
        }
        
        mutating func addTransition(from incoming: S, to outgoing: S, for event: E, callback: (() -> ())? = nil) {
            let key = AnyHashable(event)
            var store: Set<Transition> = [Transition(event: event, incoming: incoming, outgoing: outgoing, callback: callback)]
            if let existingStore = transitions[key] { store.formUnion(existingStore) }
            transitions[key] = store
        }
    }
}
