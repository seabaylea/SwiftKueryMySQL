/**
 Copyright IBM Corporation 2017

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest
import SwiftKuery
import SwiftKueryMySQL

#if os(Linux)
let tableParameters = "tableParametersLinux"
let tableNamedParameters = "tableNamedParametersLinux"
#else
let tableParameters = "tableParametersOSX"
let tableNamedParameters = "tableNamedParametersOSX"
#endif

class TestParameters: MySQLTest {

    static var allTests: [(String, (TestParameters) -> () throws -> Void)] {
        return [
            ("testParameters", testParameters),
            ("testMultipleParameterSets", testMultipleParameterSets),
            ("testNamedParameters", testNamedParameters),
        ]
    }

    class MyTable : Table {
        let a = Column("a")
        let b = Column("b")

        let tableName = tableParameters
    }

    func testParameters() {
        performTest(characterSet: "latin2", asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }
            defer {
                cleanUp(table: t.tableName, connection: connection) { _ in }
            }

            executeRawQuery("CREATE TABLE " +  packName(t.tableName) + " (a varchar(40), b integer) CHARACTER SET latin2", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            let i1 = Insert(into: t, rows: [[Parameter(), 10], ["apricot", Parameter()], [Parameter(), Parameter()]])
            executeQueryWithParameters(query: i1, connection: connection, parameters: ["apple\u{0FF9D}0FF9D", 3, "banana€euro", -8]) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            let s1 = Select(from: t)
            executeQuery(query: s1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 3")
                XCTAssertEqual(rows?[0][0] as? String, "apple\u{0FF9D}0FF9D", "Wrong value in row 0 column 0: \(String(describing: rows?[0][0])) instead of 'apple\u{0FF9D}0FF9D'")
                XCTAssertEqual(rows?[1][0] as? String, "apricot", "Wrong value in row 0 column 0: \(String(describing: rows?[1][0])) instead of 'apricot'")
                XCTAssertEqual(rows?[2][0] as? String, "banana€euro", "Wrong value in row 0 column 0: \(String(describing: rows?[2][0])) instead of 'banana€euro'")
                XCTAssertEqual(rows?[0][1] as? Int32, 10, "Wrong value in row 0 column 0: \(String(describing: rows?[0][1])) instead of 10")
                XCTAssertEqual(rows?[1][1] as? Int32, 3, "Wrong value in row 0 column 0: \(String(describing: rows?[1][1])) instead of 3")
                XCTAssertEqual(rows?[2][1] as? Int32, -8, "Wrong value in row 0 column 0: \(String(describing: rows?[2][1])) instead of -8")
            }

            let u1 = Update(t, set: [(t.a, Parameter()), (t.b, Parameter())], where: t.a == "banana€euro")
            executeQueryWithParameters(query: u1, connection: connection, parameters: ["peach", 2]) { result, rows in
                XCTAssertEqual(result.success, true, "UPDATE failed")
                XCTAssertNil(result.asError, "Error in UPDATE: \(result.asError!)")
            }

            executeQuery(query: s1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 3")
                XCTAssertEqual(rows?[2][0] as? String, "peach", "Wrong value in row 0 column 0: \(String(describing: rows?[2][0])) instead of 'peach'")
                XCTAssertEqual(rows?[2][1] as? Int32, 2, "Wrong value in row 0 column 0: \(String(describing: rows?[2][1])) instead of 2")
            }

            let raw = "UPDATE " + packName(t.tableName) + " SET a = 'banana', b = ? WHERE a = ?"
            executeRawQueryWithParameters(raw, connection: connection, parameters: [4, "peach"]) { result, rows in
                XCTAssertEqual(result.success, true, "UPDATE failed")
                XCTAssertNil(result.asError, "Error in UPDATE: \(result.asError!)")

                executeQuery(query: s1, connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "SELECT failed")
                    XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                    XCTAssertNotNil(rows, "SELECT returned no rows")
                    XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 3")
                    XCTAssertEqual(rows?[2][0] as? String, "banana", "Wrong value in row 0 column 0: \(String(describing: rows?[2][0])) instead of 'peach'")
                    XCTAssertEqual(rows?[2][1] as? Int32, 4, "Wrong value in row 0 column 0: \(String(describing: rows?[2][1])) instead of 4")
                }
            }
        })
    }

    func testMultipleParameterSets() {
        performTest(asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }
            defer {
                cleanUp(table: t.tableName, connection: connection) { _ in }
            }

            executeRawQuery("CREATE TABLE " +  packName(t.tableName) + " (a varchar(40), b integer)", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            let i1 = "insert into " + t.tableName + " values(?, ?)"
            let parametersArray = [["apple", 10], ["apricot", 3], ["banana", -8]]

            do {
                var error: Error? = nil
                let preparedStatement = try connection.prepareStatement(i1)
                defer { connection.release(preparedStatement: preparedStatement) { _ in } }

                for parameters in parametersArray {
                    connection.execute(preparedStatement: preparedStatement, parameters: parameters) { result in
                        error = result.asError
                        XCTAssertEqual(result.success, true, "INSERT failed")
                        XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
                    }
                    if error != nil {
                        break
                    }
                }
            } catch {
                XCTFail("Error in INSERT: \(error)")
            }

            let s1 = Select(from: t)
            executeQuery(query: s1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 3")
                XCTAssertEqual(rows?[0][0] as? String, "apple", "Wrong value in row 0 column 0: \(String(describing: rows?[0][0])) instead of 'apple'")
                XCTAssertEqual(rows?[1][0] as? String, "apricot", "Wrong value in row 0 column 0: \(String(describing: rows?[1][0])) instead of 'apricot'")
                XCTAssertEqual(rows?[2][0] as? String, "banana", "Wrong value in row 0 column 0: \(String(describing: rows?[2][0])) instead of 'banana'")
                XCTAssertEqual(rows?[0][1] as? Int32, 10, "Wrong value in row 0 column 0: \(String(describing: rows?[0][1])) instead of 10")
                XCTAssertEqual(rows?[1][1] as? Int32, 3, "Wrong value in row 0 column 0: \(String(describing: rows?[1][1])) instead of 3")
                XCTAssertEqual(rows?[2][1] as? Int32, -8, "Wrong value in row 0 column 0: \(String(describing: rows?[2][1])) instead of -8")
            }
        })
    }

    class NamedParametersTable: Table {
        let a = Column("a")
        let b = Column("b")

        let tableName = tableNamedParameters
    }

    func testNamedParameters() {
        performTest(asyncTasks: { connection in
            let t = NamedParametersTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }
            defer {
                cleanUp(table: t.tableName, connection: connection) { _ in }
            }

            executeRawQuery("CREATE TABLE " +  packName(t.tableName) + " (a varchar(40), b integer)", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            let i1 = Insert(into: t, rows: [[Parameter("one"), 10], ["apricot", Parameter("two")], [Parameter("three"), Parameter("four")]])
            executeQueryWithNamedParameters(query: i1, connection: connection, parameters: ["one":"apple", "three":"banana", "two": 3, "four":-8]) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            let s1 = Select(from: t)
            executeQuery(query: s1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 3")
                XCTAssertEqual(rows?[0][0] as? String, "apple", "Wrong value in row 0 column 0")
                XCTAssertEqual(rows?[1][0] as? String, "apricot", "Wrong value in row 1 column 0")
                XCTAssertEqual(rows?[2][0] as? String, "banana", "Wrong value in row 2 column 0")
                XCTAssertEqual(rows?[0][1] as? Int32, 10, "Wrong value in row 0 column 1")
                XCTAssertEqual(rows?[1][1] as? Int32, 3, "Wrong value in row 1 column 1")
                XCTAssertEqual(rows?[2][1] as? Int32, -8, "Wrong value in row 2 column 1")
            }

            let u1 = Update(t, set: [(t.a, Parameter("param")), (t.b, 2)], where: t.a == "banana")
            executeQueryWithNamedParameters(query: u1, connection: connection, parameters: ["param":"peach"]) { result, rows in
                XCTAssertEqual(result.success, true, "UPDATE failed")
                XCTAssertNil(result.asError, "Error in UPDATE: \(result.asError!)")
            }

            executeQuery(query: s1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 3")
                XCTAssertEqual(rows?[2][0] as? String, "peach", "Wrong value in row 2 column 0")
                XCTAssertEqual(rows?[2][1] as? Int32, 2, "Wrong value in row 2 column 1")

                let s2 = Select(from: t).where(t.a != Parameter("nil"))
                executeQueryWithNamedParameters(query: s2, connection: connection, parameters: ["nil":nil]) { result, rows in
                    XCTAssertEqual(result.success, true, "SELECT failed")
                }
            }

            let i2 = Insert(into: t, rows: [[Parameter("one"), 1], [Parameter("one"), 2], [Parameter("one"), Parameter("two")]])
            executeQueryWithNamedParameters(query: i2, connection: connection, parameters: ["one":"qiwi", "two": 3]) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")

                executeQuery(query: s1, connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "SELECT failed")
                    XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                    XCTAssertNotNil(rows, "SELECT returned no rows")
                    XCTAssertEqual(rows?.count, 6, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 3")
                    XCTAssertEqual(rows?[0][0] as? String, "apple", "Wrong value in row 0 column 0")
                    XCTAssertEqual(rows?[1][0] as? String, "apricot", "Wrong value in row 1 column 0")
                    XCTAssertEqual(rows?[2][0] as? String, "peach", "Wrong value in row 2 column 0")
                    XCTAssertEqual(rows?[3][0] as? String, "qiwi", "Wrong value in row 3 column 0")
                    XCTAssertEqual(rows?[4][0] as? String, "qiwi", "Wrong value in row 4 column 0")
                    XCTAssertEqual(rows?[5][0] as? String, "qiwi", "Wrong value in row 5 column 0")
                }
            }
        })
    }
}
