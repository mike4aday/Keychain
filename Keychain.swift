import Foundation

/// Simple wrapper around keychain for secure storage.
/// Adapted from https://developer.apple.com/library/content/samplecode/GenericKeychain/Listings/GenericKeychain_KeychainPasswordItem_swift.html

public final class Keychain {
	
	public enum Error: Swift.Error {
		case readFailure(status: OSStatus)
		case writeFailure(status: OSStatus)
		case deleteFailure(status: OSStatus)
		case itemNotFound(service: String, account: String)
		case itemHasNoData(service: String, account: String)
	}
	
	public static func write(data: Data, service: String, account: String) throws {
		
		do {
			// Check for an existing item in the keychain.
			try _ = read(service: service, account: account)
			
			// Update the existing item with the new password.
			var attributesToUpdate = [String : AnyObject]()
			attributesToUpdate[kSecValueData as String] = data as AnyObject?
			
			let query = buildQuery(service: service, account: account)
			let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
			
			// Throw an error if an unexpected status was returned.
			guard status == noErr else {
				throw Keychain.Error.writeFailure(status: status)
			}
		}
		catch Keychain.Error.itemNotFound {
			
			// No password was found in the keychain. Create a dictionary to save as a new keychain item.
			var newItem = buildQuery(service: service, account: account)
			newItem[kSecValueData as String] = data as AnyObject?
			
			// Add a the new item to the keychain.
			let status = SecItemAdd(newItem as CFDictionary, nil)
			
			// Throw an error if an unexpected status was returned.
			guard status == noErr else {
				throw Keychain.Error.writeFailure(status: status)
			}
		}
	}
	
	public static func read(service: String, account: String) throws -> Data  {
		
		// Build a query to find the item that matches the service and account
		var query = buildQuery(service: service, account: account)
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		query[kSecReturnAttributes as String] = kCFBooleanTrue
		query[kSecReturnData as String] = kCFBooleanTrue
		
		// Try to fetch the existing keychain item that matches the query.
		var queryResult: AnyObject?
		let status = withUnsafeMutablePointer(to: &queryResult) {
			SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
		}
		
		// Check the return status and throw an error if appropriate.
		guard status != errSecItemNotFound else {
			throw Keychain.Error.itemNotFound(service: service, account: account)
		}
		guard status == noErr else {
			throw Keychain.Error.readFailure(status: status)
		}
		
		// Parse the data from the query result.
		guard let existingItem = queryResult as? [String : AnyObject], let data = existingItem[kSecValueData as String] as? Data else {
			throw Keychain.Error.itemHasNoData(service: service, account: account)
		}
		
		return data
	}
	
	public static func delete(service: String, account: String) throws {
		
		// Delete the existing item from the keychain.
		let query = buildQuery(service: service, account: account)
		let status = SecItemDelete(query as CFDictionary)
		
		// Throw an error if an unexpected status was returned.
		guard status == noErr || status == errSecItemNotFound else {
			throw Keychain.Error.deleteFailure(status: status)
		}
	}
	
	private static func buildQuery(service: String, account: String) -> [String : AnyObject] {
		var query = [String : AnyObject]()
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrService as String] = service as AnyObject?
		query[kSecAttrAccount as String] = account as AnyObject?
		return query
	}
}
