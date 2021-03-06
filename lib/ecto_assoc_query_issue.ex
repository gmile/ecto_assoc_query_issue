defmodule EctoAssocQueryIssue do
  use Application

  def start(_type, _args) do
    children = [EctoAssocQueryIssue.Repo]

    Supervisor.start_link(children, strategy: :one_for_one, name: EctoAssocQueryIssue.Supervisor)
  end
end

defmodule EctoAssocQueryIssue.Repo do
  use Ecto.Repo,
    otp_app: :ecto_assoc_query_issue,
    adapter: Ecto.Adapters.Postgres
end

defmodule Author do
  use Ecto.Schema

  schema "authors" do
    field(:full_name, :string)
  end
end

defmodule Comment do
  use Ecto.Schema

  import Ecto.Query

  schema "comments" do
    # state is supposed to be: "pending", "approved", "disapproved"
    field(:state, :string)
    field(:post_id, :integer)

    belongs_to(:author, Author)
  end
end

defmodule Post do
  use Ecto.Schema

  schema "posts" do
    field(:title, :string)
    has_many(:moderated_comments, Comment, where: [state: {:in, ["approved", "disapproved"]}])
    has_many(:comments, Comment)
    has_many(:commenters, through: [:moderated_comments, :author])
  end
end

defmodule EctoAssocQueryIssue.Reproduce do
  import Ecto.Query

  alias EctoAssocQueryIssue.Repo

  def good do
    post = Repo.insert!(%Post{})

    Repo.insert!(%Comment{post_id: post.id, state: "approved"})
    Repo.insert!(%Comment{post_id: post.id, state: "disapproved"})
    Repo.insert!(%Comment{post_id: post.id, state: "pending"})

    Repo.all(
      from p in Post,
      where: p.id == ^post.id,
      join: mc in assoc(p, :moderated_comments),
      preload: [moderated_comments: mc]
    )
  end

  def log_test do
    require Logger

    Logger.metadata(request_id: "03872725-6411-4746-acb8-047f10aa0072")

    telemetry_fn = fn a,b,c,d ->
      case Process.info(self())[:dictionary][:"$callers"] do
        [caller_process] ->
          {:dictionary, stuff} = Process.info(caller_process, :dictionary)
          {true, log_metadata} = stuff[:logger_metadata]
          Logger.info("We're in a task process, preloading some assoc, request_id is #{log_metadata[:request_id]}")

        _ ->
          Logger.info("We've in a caller process itself")
      end
    end

    :telemetry.attach("my-handler", [:ecto_assoc_query_issue, :repo, :query], telemetry_fn, nil)

    post = Repo.insert!(%Post{})

    Repo.insert!(%Comment{post_id: post.id, state: "approved"})
    Repo.insert!(%Comment{post_id: post.id, state: "disapproved"})
    Repo.insert!(%Comment{post_id: post.id, state: "pending"})

    Repo.preload(post, [:comments, :moderated_comments])
  end

  def bad1 do
    post = Repo.insert!(%Post{})

    Repo.insert!(%Comment{post_id: post.id, state: "approved"})
    Repo.insert!(%Comment{post_id: post.id, state: "disapproved"})
    Repo.insert!(%Comment{post_id: post.id, state: "pending"})

    Repo.one(from p in Post, where: p.id == ^post.id, preload: :moderated_comments)
  end

  def bad2 do
    post = Repo.insert!(%Post{})

    Repo.insert!(%Comment{post_id: post.id, state: "approved"})
    Repo.insert!(%Comment{post_id: post.id, state: "disapproved"})
    Repo.insert!(%Comment{post_id: post.id, state: "pending"})

    Repo.preload(post, :moderated_comments, force: true)
  end
end
