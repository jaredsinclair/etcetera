//
//  GlobalTests.swift
//  EtceteraTests
//
//  Created by Jared Sinclair on 4/3/20.
//

import XCTest
import Etcetera

class GlobalTests: XCTestCase {

    func testStuf() {
        GlobalContainer.register { _ -> ColorProviding in
            ProductionColorProvider()
        }
        GlobalContainer.register { (_, microservice: Microservice) -> WebServiceProviding in
            switch microservice {
            case .posts: return PostsService()
            case .users: return UsersService()
            case .rooms: return RoomsService()
            }
        }
        let object = MyClass()
        XCTAssertEqual(object.colorProvider.accentColor, .red)
        XCTAssertEqual(object.postsProvider.fetchSomething(), "Posts")
        XCTAssertEqual(object.usersProvider.fetchSomething(), "Users")
        XCTAssertEqual(object.roomsProvider.fetchSomething(), "Rooms")
    }

}

// MARK: -

protocol ColorProviding {
    var accentColor: UIColor { get }
}

struct ProductionColorProvider: ColorProviding {
    var accentColor: UIColor { .red }
}

struct TestColorProvider: ColorProviding {
    var accentColor: UIColor { .blue }
}

// MARK: -

protocol WebServiceProviding {
    func fetchSomething() -> String
}

enum Microservice: String {
    case users
    case posts
    case rooms
}

class UsersService: WebServiceProviding {
    func fetchSomething() -> String { "Users" }
}

class PostsService: WebServiceProviding {
    func fetchSomething() -> String { "Posts" }
}

class RoomsService: WebServiceProviding {
    func fetchSomething() -> String { "Rooms" }
}

// MARK: -

class MyClass {
    @Global var colorProvider: ColorProviding
    @Global(Microservice.posts) var postsProvider: WebServiceProviding
    @Global(Microservice.users) var usersProvider: WebServiceProviding
    @Global(Microservice.rooms) var roomsProvider: WebServiceProviding
}
