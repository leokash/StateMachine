//
//  StateMachine.swift
//  StateMachine
//
//  Created by Nkashama Kabeya on 01/10/2023.
//

import Foundation

protocol Machine {
    func add(transition: any Transition)
    func handle(event: any Event, completion: @escaping (Result<any State, Error>) -> ())
}

extension Machine {
    func handle(event: any Event) {
        handle(event: event) { _ in }
    }
}

protocol Cancellable {
    func cancel()
}

protocol Transition: Hashable {
    associatedtype E: Event
    associatedtype S: State
    
    var event: E { get }
    var incoming: S { get }
    var onTransitioned: (any State) -> () { get }
}

private extension Transition {
    func canTransition(from state: any State) -> Bool {
        self.incoming.hashValue == state.hashValue
    }
}

protocol DefaultTransition: Transition {
    func process() -> any State
}

protocol AsyncTransition: Transition, Cancellable {
    func process(_ completion: (any State) -> ())
}

enum StateMachine {
    enum Errors: Error {
        case cancelled, machineUnavailable
    }
    
    private class ConcreteMachine: Machine {
        private var current: any State
        private var transitions: [AnyHashable: Set<AnyHashable>] = [:]
        
        init(with state: any State, transitions: [any Transition]) {
            self.current = state
            self.transitions = Self.map(transitions: transitions)
        }
        
        func add(transition: any Transition) {
            Self.add(transition: transition, into: &transitions)
        }
        
        private let mutex = DispatchQueue(label: "")
        
        func handle(event: any Event, completion: @escaping (Result<any State, Error>) -> ()) {
            let key = AnyHashable(event)
            mutex.async { [self] in
                if let transition = transitions[key]?.first(where: { ($0.base as? any Transition)?.canTransition(from: current) ?? false})?.base as? any Transition {
                    let group = DispatchGroup()
                    if let transition = transition as? any AsyncTransition {
                        group.enter()
                        handleAsync(transition: transition, for: group, completion: completion)
                        return
                    }
                            
                    if let transition = transition as? any DefaultTransition {
                        current = transition.process()
                        completion(.success(current))
                        transition.onTransitioned(current)
                    }
                } else {
                    print("***** no transition found for \(event), coming from \(current) *****")
                }
            }
        }
        
        static private let timerTimeout: TimeInterval = 5
        
        private func handleAsync(transition: any AsyncTransition, for dispatchGroup: DispatchGroup, completion: @escaping (Result<any State, Error>) -> ()) {
            var cancelled = false
            let timer = Timer(timeInterval: Self.timerTimeout, repeats: false) { _ in
                cancelled = true
                transition.cancel()
                dispatchGroup.leave()
                completion(.failure(Errors.cancelled))
                print("processing took long... cancelling \(transition.event)")
            }
            
            RunLoop.main.add(timer, forMode: .default)
            transition.process { [weak self] newState in
                if cancelled { return }
                
                timer.invalidate()
                guard let self else {
                    completion(.failure(Errors.machineUnavailable))
                    return
                }
                
                current = newState
                dispatchGroup.leave()
                completion(.success(newState))
                transition.onTransitioned(newState)
            }
        }
        
        private static func map(transitions: [any Transition]) -> [AnyHashable: Set<AnyHashable>] {
            var dictionary: [AnyHashable: Set<AnyHashable>] = [:]
            transitions.forEach { add(transition: $0, into: &dictionary) }
            
            return dictionary
        }
        
        private static func add(transition: any Transition, into dictionary: inout [AnyHashable: Set<AnyHashable>]) {
            let key = AnyHashable(transition.event)
            var store: Set<AnyHashable> = [AnyHashable(transition)]
            if let savedStore = dictionary[key] { store.formUnion(savedStore) }
            dictionary[key] = store
        }
    }
    
    static func machine<S: State>(with state: S, @TransitionBuilder _ transitions: () -> [any Transition]) -> any Machine {
        ConcreteMachine(with: state, transitions: transitions())
    }
    
    @resultBuilder
    enum TransitionBuilder {
        static func buildBlock(_ components: any Transition...) -> [any Transition] {
            components
        }
    }
}
