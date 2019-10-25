# Syncify

Syncify is a gem used to sync ActiveRecord records and their associations from one remote environment to your local environment.

Consider this hypothetical problem: You have a gigantic production database with complex associations between your models, including polymorphic associations. The database includes sensitive data that shouldn't really be in your development or staging environments. But, there's something wrong in production and you need production data to be able to debug it. It's not practical, efficient, safe, or generally advisable to restore a backup of the production database locally.

How do you get that data safely from production to an environment where you can make use of it? This is the problem that Syncify aims to address.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'syncify'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install syncify

## Usage

Syncify doesn't require Rails, just ActiveRecord, but it's a reasonable foundation for the following examples.

Also, you can sync from any environment to whatever your current environment is. So, you could sync from your staging environment to your client test environment or from staging to development. Heck, you could go from staging to prod if you'd like.

For the purposes of this documentation we'll assume that you're syncing data in a Rails app from production to your local development environment.

Syncify has a pretty simple API. There's just one method, `run!`. Here's a really basic example where we're syncing a single `Widget` from production to the current environment. The current environment could be any environment, but we'll assume it's development for this documentation.

```ruby
Syncify::Sync.run!(klass: Widget, id: 123, remote_database: :production)
```

Boom! You've copied `Widget` 123 to local dev. The widget will have all the same values including its `id`, `created_at`, `updated_at`, etc values. The above example assumes that the `Widget` doesn't have any foreign keys that don't exist locally.

Syncify also accepts a `where` argument in the form of any valid active record `where` expression (a hash or a string). Here's the same as above, but with a `where`:

```ruby
Syncify::Sync.run!(klass: Widget, where: { id: 123 }, remote_database: :production)
```

Or...


```ruby
Syncify::Sync.run!(klass: Widget, where: 'widgets.id = 123', remote_database: :production)
```

Now, let's say a `Widget` `belongs_to` a `Manufacturer`. Furthermore, let's say a `Manufacturer` `has_many` `Widget`s. We'll pretend we have this data in the prod database:

`widgets`:

| id  | name                                               | manufacturer_id |
| --- | -------------------------------------------------- | --------------- |
| 123 | Lubricated Stainless Steel Helical Insert          | 78              |
| 124 | Magnetic Contact Alarm Switches                    | 79              |
| 125 | Idler Sprocket for Double-Strand ANSI Roller Chain | 78              |
| 126 | Rod End Bolt Blank                                 | 79              |
| 127 | Press-Fit Drill Bushing                            | 78              |

`manufacturers`:

| id  | name                       |
| --- | -------------------------- |
| 78  | South Seas Trading Company |
| 79  | Blandco Manufacturing      |

If your database uses foreign keys and the production `Widget`'s `Manufacturer` doesn't exist locally then the example above would fail. To get around this we can specify an association to also sync when syncing the `Widget`.

```ruby
Syncify::Sync.run!(klass: Widget,
                   id: 123,
                   association: :manufacturer,
                   remote_database : :production)
```

Running the above example will copy two records into your local database:

* The `Widget` with id 123 (Lubricated Stainless Steel Helical Insert)
* The `Manufacturer` with id 78 (South Seas Trading Company)

It's important to note that Syncify _does not_ recursively follow associations (though see below for how to discover associations programmatically). You'll note that not all of the the manufacturer's widgets were synced, only the one we specified.

The `association` attribute passed into the `run!` method can be any valid value that you might use when joining records with ActiveRecord. The above effectively becomes:

```ruby
Widget.eager_load(:manufacturer).find(123)
```

Because of this, you can pass any sort of ActiveRecord association into Syncify's `run!` method.

Now let's imagine that a `Manufacturer` `has_many` `Plant`s which `belong_to` a `State`. Here are some example rows in these tables:

`plants`:

| id  | name            | manufacturer_id | city    | state_id |
| --- | --------------- | --------------- | ------- | -------- |
| 64  | Rapid Run       | 78              | Lansing | 13       |
| 65  | Ye Olde Factory | 78              | Naples  | 15       |
| 66  | Catco           | 79              | Balston | 43       |

`states`:

| id  | name     |
| --- | -------- |
| 13  | Michigan |
| 15  | Florida  |
| 43  | Virginia |

We could sync a `Manufacturer` along with its widgets, factories, and the state the factory is in with this example:

```ruby
Syncify::Sync.run!(klass: Manufacturer,
                   id: 78,
                   association: [
                     :widgets,
                     { factories: :state }
                   ],
                   remote_database: :production)
```

You can really go wild with the associations; well beyond what you could normally run with an ActiveRecord query!

> When Syncify was first released, I had an app with a hash defining a ton of associations across dozens of models that was more than 150 lines long. When I ran this sync it would identify more than 500 records and syncs them all to local dev in about 30 seconds. I've since updated to use association discovery (documented below) and sync _much_ more data. It takes longer, but it's still very fast.

### Polymorphic Associations

Syncify also works with (and across) Polymorphic associations! To sync across polymorphic associations you need to specify an association using the `Syncify::PolymorphicAssociation` class. This is put in place in your otherwise-normal associations.

Let's imagine that we run an online store that sells both physical and digital goods. A given invoice then might have line items that refer to either type of good.

Here's our model:

* `Customer`
	* `has_many :invoices`
* `Invoice`
	* `belongs_to :customer`
	* `has_many :line_items`
* `LineItem`
	* `belongs_to :invoice`
	* `belongs_to :product, polymorphic: true`
* `DigitalProduct`
	* `has_many :line_items, as: :product`
	* `belongs_to :category`
* `PhysicalProduct`
	* `has_many :line_items, as: :product`
	* `belongs_to :distributor`
* `Category`
	* `has_many :digital_products`
* `Distributor`
	* `has_many :physical_products`

There's a lot going on above, and I'll spare you the example database tables. You can use your imagination! 😉

Let's say we want to sync a particular `LineItem`. With ActiveRecord queries, you can't simply `eager_load` across a polymorphic association, much less to any sub-associations (EG: `:category` or `:distributor`). With Syncify you can.

Here's an example. For simplicity's sake it assumes that the database doesn't use foreign keys. (Don't worry, we'll do a more complex example next!):

```ruby
Syncify::Sync.run!(klass: LineItem,
                   id: 42,
                   association: {
                     product: {
                       DigitalProduct => {},
                       PhysicalProduct => {}
                     }
                   },
                   remote_database: :production)
```

Assuming that line item 42's product is a `DigitalProduct`, this example would have synced the `LineItem` and its `DigitalProduct` and nothing else.

Let's focus in on the association:

```ruby
{
  product: {
    DigitalProduct => {},
    PhysicalProduct => {}
  }
}
```

We know the `LineItem` has a polymorphic association named `:product` (this is documented above). This association is saying that, for the `LineItem`'s `product` polymorphic association, when the product is a `DigitalProduct`, sync it with the specified associations (in this case none). When the product is a `PhysicalProduct`, sync it with the specified associations (again, none in this case).

Now let's say that we want to sync a specific `Customer` and all of their invoices and the related products. IE: the whole kit and caboodle. Here's how you can do it:

```ruby
Syncify::Sync.run!(klass: Customer,
                   id: 999,
                   association: {
                     invoices: {
                       line_items: {
                         product: {
                           DigitalProduct => :category,
                           PhysicalProduct => :distributor
                         }
                       }
                     }
                   },
                   remote_database: :production)
```

This will sync a customer, all of their invoices, and all of those invoice's line items. It goes on to sync all of the line item's products, whether digital or physical, as well as the digital product's category and the physical product's distributor.

### Discovering Associations Programmatically

The process of specifying associations, as outlined above, might be fairly tedious, especially if you have a hierarchy of dozens of interrelated models. For this reason, Syncify also includes a class that can discover associations, `Syncify::IdentifyAssociations`. Like `Syncify::Sync`, this class has one method, `run!`. You can use it like this:

```ruby
associations = Syncify::IdentifyAssociations.run!(klass: Customer)
```

This will inspect the local `Customer` class, discover its associations, and then drill down through those associations to discover nested associations. It proactively cuts out associations that are inverses of other associations, and endeavors to eradicate association loops. So, looking at the customer/invoices/products example above, it will recognize the association from `Customer` to `Invoice`, but not from `Invoice` to `Customer`, since it's the inverse of the first association. It also skips over `has_many through:` associations, since those _must_ be covered by another association.

Using the example above, the associations identified would look like this:

```ruby
{
  invoices: {
    line_items: {
      product: {
        DigitalProduct => :category,
        PhysicalProduct => :distributor
      }
    }
  }
}
```

> Important Note: Polymorphic associations are discovered by querying the database for associated types. So, in the example above, the `IdentifyAssociations` class sees the `LineItem#products` association and queries the `line_items` table for the set of distinct values in the `product_type` column. It uses that to continue discovery. So, if you're trying to discover associations, but your database is empty, you won't be able to traverse these polymorphic associations.

The example above can be see in the specs at spec/lib/syncify/identify_associations_spec.rb.

So, you can combine the `Sync` class and the `IdentifyAssociations` class to make your live even easier:

```ruby
Syncify::Sync.run!(
  klass: Customer,
  id: 999,
  association: Syncify::IdentifyAssociations.run!(klass: Customer),
  remote_database: :production
)
```

#### Using `IdentifyAssociations` Remotely

Under some circumstances you may want to discover the associations from the remote database. For example, maybe you don't have data in your local database to be able to discover polymorphic associations. For situations like this, `IdentifyAssociations` accepts a `remote_database` argument, just like `Sync`.

```ruby
Syncify::IdentifyAssociations.run!(klass: Customer, remote_database: :production)
```

And here it is with `Sync` in all its glory:

```ruby
Syncify::Sync.run!(
  klass: Customer,
  id: 999,
  association: Syncify::IdentifyAssociations.run!(klass: Customer, remote_database: :production),
  remote_database: :production
)
```

#### Association Hints

Sometimes, you might not want to automatically discover associations, but not _all_ of them. In these situations you can use hints. A hint is a class that can be used to filter out associations conditionally.

The `Hint` class defines the interface for hints. It's a no-op hint that doesn't filter anything. If you need to create your own hints you can extend `Hint`.

All hints have two methods:

| Method                               | Description                                                                                                                                                                                                                                                                                                   |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `applicable?(candidate_association)` | This method take a Rails association (not a Syncify association, which isn't documented here) and returns a boolean value indicating whether or not the hint is applicable for the specified association. Basically, this is what Syncify uses to determine whether or to check if an association is allowed. |
| allowed?`                            | This method returns true or false, indicating if a particular association is allowed to be traversed or not.                                                                                                                                                                                                  |

You are most likely to use the `BasicHint` class. This class has a constructor that accepts the following arguments:

| Argument      | Type                                | Default | Description                                                                                                                                                                                |
| ------------- | ----------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `from_class`  | Class or array of classes           | nil     | If provided, the `from_class` argument declares that the hint applies to associations from the specified class or classes.                                                                 |
| `association` | Symbol or array of symbols or regex | nil     | If provided, the `association` argument declares that the hint applies to associations with the specified name or names or names matching the specified regular expression.                |
| `to_class`    | Class or array of classes           | nil     | If provided, the `to_class` argument declares that the hint applies to associations to the specified class or classes.                                                                     |
| `allowed`     | Boolean (required)                  |         | This argument indicates that if the hint is applicable to a particular association that it is or is not allowed, meaning that the `IdentifyAssociations` class will or will not ignore it. |

Hints can be specified for use by `IdentifyAssociations` like so:

```ruby
Syncify::IdentifyAssociations.run!(
  klass: Customer,
  hints: [
    Syncify::Hint::BasicHint.new(....),
    Syncify::Hint::BasicHint.new(....)
  ]
```

Hints are applied in the order specified and the first one that matches "wins". So, if you have an association that is explicitly disallowed by a hint before another hint allows it, the first hint wins and the association is ignored.

With that out of the way, let's assume you have an an association where there are lots of associated records. For example, maybe you're Amazon and you have a `Store` class which has many `Product`s. Obviously, amazon has a bazillion products. We might not want to sync all of these products when syncing a `Store`. You could filter that out with hints in a couple ways.

Don't sync by association name:

```ruby
Syncify::Hint::BasicHint.new(association: :products, allowed: false)
```

Don't sync by the target class name:

```ruby
Syncify::Hint::BasicHint.new(to_class: Product, allowed: false)
```

Perhaps some models always exist locally and remotely. In that case, you could create a hint to never sync them:

```ruby
Syncify::Hint::BasicHint.new(
  to_class: [
    Config,
    Account,
    Country,
    SiteDomain,
    Offer
  ]
)
```

Perhaps you have some classes where none of their associations ever need to be synced. For example, maybe you collect stats on some objects, but the stats aren't needed locally, or there's so many records that it's not practical to sync them all:

```ruby
Syncify::Hint::BasicHint.new(
  from_class: [
    Account,
    DailyStat,
    LifetimeDailyStat,
    DomainDailyStat,
    PaymentAccount,
    User,
  ],
  allowed: false
)
```

Note that in the above example we're disallowing _all_ associations from `Account`. But, let's imagine that `Account` has 50 associations and we _do_ want to sync two of them. Since hints are applied in the order specified, and the first hint that matches is the hint that is applied, you could specifically allow two of the associations from `Account`, but disallow all others like this:

```ruby
Syncify::Hint::BasicHint.new(from_class: Account, association: [:example1, :example2], allowed: true)
Syncify::Hint::BasicHint.new(from_class: Account, allowed: false)
```

If the `BasicHint` class isn't sufficient for your needs, you can always create your own hints by extending `Hint` and implementing the `applicable?` and `allowed?` methods.

### Callbacks

Sometimes production databases contain sensitive data that you really don't want to have end up in other environments. Or, maybe you want to disassociate production data from third party production APIs. Or maybe you want to download images before you actually create image records locally. Syncify handles this by providing a callback mechanism.

Syncify's workflow is basically this:

1. Using the specified class and its associations, Syncify identifies all of the records we need to sync to the local environment. Effectively, all of the records are loaded from the remote environment into a set in memory.
2. Syncify calls an optional `callback` proc you can pass into the `run!` method.
3. Syncify actually bulk inserts all of the identified records into the local database.

By providing a `callback` proc, you can take some sort of action after all of the remote data has been identified, but before you write it locally. This includes modifying the remote data (in memory, not actually in the remote database).

Here's an example that masks personally identifiable information for users:

```ruby
Syncify::Sync.run!(klass: User,
                   id: 40,
                   remote_database: :production,
                   callback:
                     proc do |identified_records|
                       user = identified_records.find { |record| record.class == User }
                       user.first_name = "#{user.first_name.first}#{'*' * (user.first_name.size - 1)}"
                       user.last_name = "#{user.last_name.first}#{'*' * (user.last_name.size - 1)}"
                     end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dhughes/syncify.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
