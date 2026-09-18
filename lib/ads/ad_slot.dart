/// Every place an ad is allowed to appear. Spec §11 is explicit and
/// absolute: zero ad placements on Session Player, Session Setup, Recap, or
/// Clip review. Rather than trust every call site to check that rule, this
/// enum simply has no member for those screens — there is no [AdSlot] value
/// a Player/Setup/Recap/Clip screen could pass to `BannerAdWidget`, so the
/// restriction is enforced by the type system, not by convention.
enum AdSlot { train, footage, progress }
