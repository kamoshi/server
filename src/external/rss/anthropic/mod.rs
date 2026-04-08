pub mod alignment;
pub mod red;
pub mod research;
pub mod transformer_circuits;

use super::{FeedGroup, FeedItem};

const FEEDS: &[FeedItem] = &[
    FeedItem::new(
        "/rss/anthropic/research",
        research::TITLE,
        research::DESCRIPTION,
    ),
    FeedItem::new("/rss/anthropic/red", red::TITLE, red::DESCRIPTION),
    FeedItem::new(
        "/rss/anthropic/transformer-circuits",
        transformer_circuits::TITLE,
        transformer_circuits::DESCRIPTION,
    ),
    FeedItem::new(
        "/rss/anthropic/alignment",
        alignment::TITLE,
        alignment::DESCRIPTION,
    ),
];

pub const GROUP: FeedGroup = FeedGroup::new("Anthropic", FEEDS);
