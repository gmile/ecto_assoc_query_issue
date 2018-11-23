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

  def moderated_comments do
    dynamic([c], c.state in ^["approved", "disapproved"])
  end
end

defmodule Post do
  use Ecto.Schema

  schema "posts" do
    field(:title, :string)
    has_many(:moderated_comments, Comment, where: {Comment, :moderated_comments, []})
    has_many(:commenters, through: [:moderated_comments, :author])
  end
end

defmodule EctoAssocQueryIssue.Reproduce do
  import Ecto.Query

  def good do
    query = from(p in Post, join: c in assoc(p, :moderated_comments))

    EctoAssocQueryIssue.Repo.all(query)
  end

  def bad do
    query = from(p in Post, join: c in assoc(p, :commenters))

    EctoAssocQueryIssue.Repo.all(query)
  end
end
