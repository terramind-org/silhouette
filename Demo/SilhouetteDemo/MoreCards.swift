import Silhouette
import SwiftUI

// More everyday cards for the showcase and the docs. People are made up; avatars are initials on
// a gradient, never anyone's photo.

// MARK: - Comments

struct Comment: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var initials: String
    var time: String
    var text: String
    var likes: Int

    static let sample: [Comment] = [
        Comment(id: 0, name: "Sample Name", initials: "SN", time: "2h", text: "A comment of a usual length, long enough to wrap onto a second line.", likes: 88),
        Comment(id: 1, name: "Another Name", initials: "AN", time: "3h", text: "A short reply, one line.", likes: 8),
        Comment(id: 2, name: "Third Person", initials: "TP", time: "5h", text: "A longer thought that runs across the card and wraps onto a second line, then a third one.", likes: 88),
    ]
    static let real: [Comment] = [
        Comment(id: 0, name: "Maya Okafor", initials: "MO", time: "2h", text: "The skeleton matching the real layout is the part I didn't know I wanted.", likes: 24),
        Comment(id: 1, name: "Jonas Weber", initials: "JW", time: "3h", text: "Shipping this on Friday.", likes: 6),
        Comment(id: 2, name: "Priya Raman", initials: "PR", time: "5h", text: "Tried it on a slow train. The page stayed put, the lines came in top to bottom, and nothing jumped.", likes: 41),
    ]
}

struct CommentsCard: View {
    var comments: [Comment]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Comments").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("\(comments.count)").font(.system(size: 15)).foregroundStyle(Palette.secondary)
                }
                ForEach(comments) { comment in
                    HStack(alignment: .top, spacing: 12) {
                        Avatar(initials: comment.initials, size: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(comment.name).font(.system(size: 15, weight: .semibold))
                                Text(comment.time).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                            }
                            Text(comment.text).font(.system(size: 15))
                            HStack(spacing: 14) {
                                Label("\(comment.likes)", systemImage: "heart")
                                Text("Reply")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.secondary)
                            .labelStyle(.titleAndIcon)
                            .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Profile header

struct ProfileHeader: Codable, Hashable {
    var name: String
    var handle: String
    var initials: String
    var bio: String
    var posts: String
    var followers: String
    var following: String

    static let sample = ProfileHeader(
        name: "Sample Person", handle: "@samplehandle", initials: "SP",
        bio: "A bio of a usual length that wraps onto a second line on a phone.",
        posts: "888", followers: "88.8k", following: "888"
    )
    static let real = ProfileHeader(
        name: "Lina Kowalski", handle: "@lina.k", initials: "LK",
        bio: "Type designer. Drawing letters that read well at 9 pt and look good at 90.",
        posts: "312", followers: "18.4k", following: "201"
    )
}

struct ProfileHeaderCard: View {
    var profile: ProfileHeader

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Palette.gradient(for: profile.name + "cover")
                    .frame(height: 86)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .bottom) {
                        Avatar(initials: profile.initials, size: 72)
                            .overlay(Circle().strokeBorder(Palette.card, lineWidth: 4))
                            .offset(y: -36)
                            .padding(.bottom, -36)
                        Spacer()
                        Text("Follow")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.85))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(Palette.accent, in: Capsule())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name).font(.system(size: 22, weight: .bold))
                        Text(profile.handle).font(.system(size: 15)).foregroundStyle(Palette.secondary)
                    }
                    Text(profile.bio).font(.system(size: 15))
                    HStack(spacing: 22) {
                        stat(profile.posts, "Posts")
                        stat(profile.followers, "Followers")
                        stat(profile.following, "Following")
                    }
                    .padding(.top, 2)
                }
                .padding(18)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.system(size: 15, weight: .semibold))
            Text(label).font(.system(size: 15)).foregroundStyle(Palette.secondary)
        }
    }
}

// MARK: - Listing

struct Listing: Codable, Hashable {
    var title: String
    var place: String
    var dates: String
    var price: String
    var rating: String
    var picture: Int? = nil

    static let sample = Listing(title: "A cabin by the water", place: "Somewhere, Country", dates: "8–8 Nov", price: "£888", rating: "8.88")
    static func real() -> Listing {
        Listing(title: "Cabin on the fjord", place: "Balestrand, Norway", dates: "14–18 Dec", price: "£540", rating: "4.96", picture: Int.random(in: 0..<100_000))
    }
}

struct ListingCard: View {
    var listing: Listing

    var body: some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 12) {
                SkeletonAsyncImage(url: galleryURL(listing.picture)) { image in
                    image.resizable().scaledToFill()
                }
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(listing.title).font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Label(listing.rating, systemImage: "star.fill")
                            .font(.system(size: 14, weight: .medium))
                            .labelStyle(.titleAndIcon)
                    }
                    Text(listing.place).font(.system(size: 15)).foregroundStyle(Palette.secondary)
                    Text(listing.dates).font(.system(size: 15)).foregroundStyle(Palette.secondary)
                    HStack(spacing: 4) {
                        Text(listing.price).font(.system(size: 15, weight: .semibold))
                        Text("for 4 nights").font(.system(size: 15))
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - Feed post

struct FeedPost: Codable, Hashable {
    var name: String
    var initials: String
    var time: String
    var text: String
    var likes: String
    var replies: String
    var picture: Int? = nil

    static let sample = FeedPost(
        name: "Sample Name", initials: "SN", time: "8m",
        text: "A post of a usual length, long enough to run onto a second line of the card.",
        likes: "888", replies: "88"
    )
    static func real() -> FeedPost {
        FeedPost(
            name: "Tomás Herrera", initials: "TH", time: "12m",
            text: "First light over the valley this morning. Worth the 5 am start.",
            likes: "1.2k", replies: "84", picture: Int.random(in: 0..<100_000)
        )
    }
}

struct FeedPostCard: View {
    var post: FeedPost

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Avatar(initials: post.initials, size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.name).font(.system(size: 15, weight: .semibold))
                        Text(post.time).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Image(systemName: "ellipsis").foregroundStyle(Palette.secondary).skeletonIgnored()
                }
                Text(post.text).font(.system(size: 16))
                SkeletonAsyncImage(url: galleryURL(post.picture)) { image in
                    image.resizable().scaledToFill()
                }
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                HStack(spacing: 18) {
                    Label(post.likes, systemImage: "heart")
                    Label(post.replies, systemImage: "bubble.left")
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .labelStyle(.titleAndIcon)
            }
        }
    }
}
