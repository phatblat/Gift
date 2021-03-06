import Foundation
import LlamaKit
import ReactiveCocoa

private let tagEnumerationOver: Int32 = -1987

public extension Repository {
  /**
    Enumerates over all tags in a repository.

    :returns: A signal that sends subscribers tag references as they're
              enumerated, or an error to indicate what went wrong during
              the enumeration.
  */
  public func tags() -> SignalProducer<Reference, NSError> {
    return SignalProducer { (observer, disposable) in
      let errorCode = gift_tagForEach(self.cRepository) { (referenceName, referenceObjectID) in
        if disposable.disposed {
          return tagEnumerationOver
        }

        let reference = Reference.lookup(referenceName, cRepository: self.cRepository)
        switch reference {
          case .Success(let boxedReference):
            sendNext(observer, boxedReference.unbox)
            return GIT_OK.value
          case .Failure(let boxedError):
            sendError(observer, boxedError.unbox)
            return tagEnumerationOver
        }
      }

      if errorCode == GIT_OK.value {
        sendCompleted(observer)
      } else if errorCode == GIFTTagForEachCallbackPayloadError {
        let description = "An error occurred when attempting to enumerate tags in a repository."
        sendError(observer, NSError.giftError(.CFunctionCallbackConversionFailure, description: description))
      } else if errorCode != tagEnumerationOver {
        sendError(observer, NSError.libGit2Error(errorCode, libGit2PointOfFailure: "git_tag_foreach"))
      }
    }
  }

  /**
    A list of tag names in the repository.

    :param: matchingPattern If a pattern is provided, only the tags
                            matching this pattern are returned.
    :returns: Either a list of tag names matching the given pattern (if any),
              or a failure indicating what went wrong when retrieving the tags.
  */
  public func tagNames(matchingPattern: String = "*") -> Result<[String], NSError> {
    var out = git_strarray(strings: nil, count: 0)
    let errorCode = git_tag_list_match(&out, matchingPattern, cRepository)
    if errorCode == GIT_OK.value {
      let names = strings(out)
      git_strarray_free(&out)
      return names
    } else {
      return failure(NSError.libGit2Error(errorCode, libGit2PointOfFailure: "git_tag_list_match"))
    }
  }
}
