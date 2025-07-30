# Up and Running

You can run `mix combo.new` from any directory. It will accept either an absolute or relative path for the directory of the new project. Assuming that the name of our project is `hello`, let's run the following command:

```console
$ mix combo.new hello
```

Then, it will generate all required files:

```console
* creating hello/config/config.exs
* creating hello/config/dev.exs
* creating hello/config/prod.exs
...

Fetch and install dependencies? [Yn]
```

> The generated project assumes that the PostgreSQL database will have a `postgres` user account with the correct permissions and a password of "postgres".

When it's done, it will ask you if you want it to install dependencies. Let's say yes to that.

```console
Fetch and install dependencies? [Yn] Y
* running mix deps.get
* running mix assets.setup
* running mix deps.compile

We are almost there! The following steps are missing:

    $ cd hello

Then configure your database in config/dev.exs and run:

    $ mix ecto.create

Start your Phoenix app with:

    $ mix combo.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix combo.server
```

Once dependencies are installed, the task will prompt you what to do next. Let's give it a try.

First, `cd` into the `hello/` directory:

```console
$ cd hello
```

Create the database:

```console
$ mix ecto.create
Compiling 13 files (.ex)
Generated hello app
The database for Hello.Repo has been created
```

In case the database could not be created, see [the Ecto section on Mix tasks](ecto.html#mix-tasks) or run `mix help ecto.create`.

Start the Combo server:

```console
$ mix combo.server
[info] Running HelloWeb.Endpoint with Bandit 1.5.7 at 127.0.0.1:4000 (http)
[info] Access HelloWeb.Endpoint at http://localhost:4000
[watch] build finished, watching for changes...
...
```

By default, Combo server accepts requests on port 4000. When accessing [http://localhost:4000](http://localhost:4000), you should see the welcome page.

![Welcome Page](assets/images/welcome-to-phoenix.png)

If your screen looks like the image above, congratulations! You now have a working Combo project.

To stop it, hit `ctrl-c` twice.

Now, you are ready to explore the Combo world.

You can continue reading these guides to have a quick introduction into all the parts that make your Phoenix application. If that's the case, you can read the guides in any order or start with our guide that explains the [directory structure](directory_structure.html).
